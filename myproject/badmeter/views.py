
from django.http import HttpResponse
from django.db import connection
from django.shortcuts import redirect
from django.views.generic import TemplateView
from django.views.generic.edit import FormView
from django.contrib import messages
from django.core.urlresolvers import reverse_lazy
from django.utils.text import slugify
from myproject import settings
from .models import Topic, Vote, Cookie, CheckModelSave
from .forms import TopicModelForm, VoteModelForm
from .misc import print_info, strip_extra_spaces, ageindays_string
import sys
import json
import re


def search(request):
    search_str = strip_extra_spaces(request.GET.get('term', ''))
    cursor = connection.cursor()
    cursor.execute('SELECT id, topic_slug, topic_title FROM list_topics(%s)', [search_str])
    rows = [{'id':row[0],'link':row[1],'label':row[2],'value':row[2]} for row in cursor.fetchall()]
    return HttpResponse(json.dumps(rows), content_type="application/json")


class SessionViewMixin(object):
    def dispatch(self, request, *args, **kwargs):
        messages.set_level(request, messages.DEBUG)
        if request.session.test_cookie_worked():
            request.session.delete_test_cookie()
        else:
            messages.info(request, 'This website uses cookies.')

        request.session.set_test_cookie()
        return super(SessionViewMixin, self).dispatch(request, *args, **kwargs)


class StatsTableMixin(object):
    def get_context_data(self, **kwargs):
        context = super(StatsTableMixin, self).get_context_data(**kwargs)
        cookie_string = self.initial.get('cookie_string','')
        topic_slug = self.initial.get('topic_slug','')

        topic = Topic.objects.filter(topic_slug=topic_slug)
        cookie = Cookie.objects.filter(cookie_string=cookie_string, topic=topic)

        if cookie:
            context.update({
                'cookie_string' : cookie[0].cookie_string,
                'cookie_ageindays_string' : ageindays_string(cookie[0].date_created),
                'cookie_total_votes' : (cookie[0].votes_positive + cookie[0].votes_negative),
                'cookie_votes_positive' : cookie[0].votes_positive,
                'cookie_votes_negative' : cookie[0].votes_negative})
        else:
            context.update({
                'cookie_string' : cookie_string,
                'cookie_ageindays_string' : 0,
                'cookie_total_votes' : 0,
                'cookie_votes_positive' : 0,
                'cookie_votes_negative' : 0})

        if topic:
            context.update({
                'topic_ageindays_string' : ageindays_string(topic[0].date_created),
                'topic_total_votes' : (topic[0].votes_positive + topic[0].votes_negative),
                'topic_votes_positive' : topic[0].votes_positive,
                'topic_votes_negative' : topic[0].votes_negative,
                'topic_badmeter' : topic[0].badmeter,
                'topic_created' : topic[0].date_created})
        else:
            context.update({
                'topic_ageindays_string' : 0,
                'topic_total_votes' : 0,
                'topic_votes_positive' : 0,
                'topic_votes_negative' : 0,
                'topic_badmeter' : 50,
                'topic_created' : '0000-00-00'})

        cursor = connection.cursor()
        cursor.execute('SELECT purge_date, vote_needed FROM get_purgedate(%s)', [topic_slug,])
        topic_purge = cursor.fetchall()

        if topic_purge[0][0]:
            context.update({
                'topic_purgedate' : '%s, needed votes: %s' % (topic_purge[0][0], topic_purge[0][1])})
        else:
            # New topic so no purge-date yet then just get from configuration setting.
            cursor.execute('SELECT interval_days::text, vote_quota FROM get_configuration()')
            topic_purge = cursor.fetchall()
            context.update({
                'topic_purgedate' : '%s, needed votes: %s' % (topic_purge[0][0], topic_purge[0][1])})

        cursor.execute('SELECT status_message FROM get_status_message(%s, %s)',
            [topic_slug, cookie_string])
        status_message = cursor.fetchall()
        context.update({
            'status_message' : status_message[0][0],
            'allow_vote' : (re.search('can vote today.', status_message[0][0]) is not None)})
        return context


class HomeTemplateView(SessionViewMixin, TemplateView):
    template_name = 'home.html'

    def get_context_data(self, **kwargs):
        context = super(HomeTemplateView, self).get_context_data(**kwargs)
        context['topic_badmeter'] = 50

        if not settings.TESTING:
            # Grab from configuration setting.
            cursor = connection.cursor()
            cursor.execute('SELECT interval_days::text, vote_quota FROM get_configuration()')
            topic_purge = cursor.fetchall()
            context['interval_days'] = topic_purge[0][0]
            context['vote_quota'] = topic_purge[0][1]

        return context


class TopicFormView(SessionViewMixin, StatsTableMixin, FormView):
    model = Topic
    fields = ['topic_title', 'cookie_string', 'recaptcha_challenge_field', 'recaptcha_response_field']
    template_name = 'new_topic.html'
    form_class = TopicModelForm

    def dispatch(self, request, *args, **kwargs):
        topic_title = strip_extra_spaces(request.POST.get('topic_title'))
        topic_slug = slugify(unicode(topic_title))

        topic = self.model.objects.filter(topic_title__istartswith=topic_title).order_by('topic_title')
        if topic and topic_slug:
            topic_slug = topic[0].topic_slug
            return redirect('/vote/%s' % topic_slug, permanent=True)

        self.initial = {
            'topic_title' : topic_title,
            'topic_slug' : topic_slug,
            'cookie_string' : request.session.session_key,
            'public_key' : settings.PUBLIC_KEY}
        return super(TopicFormView, self).dispatch(request, *args, **kwargs)

    def get_form_kwargs(self):
        kwargs = super(TopicFormView, self).get_form_kwargs()
        if not settings.TESTING:
            kwargs['request'] = self.request
        return kwargs

    def form_valid(self, form):
        form.store()
        if form.errors:
            return self.form_invalid(form)
        else:
            self.success_url = '/vote/%s' % self.initial.get('topic_slug','')
            return super(TopicFormView, self).form_valid(form)


class VoteFormView(SessionViewMixin, StatsTableMixin, FormView):
    model = Vote
    fields = ['topic_slug', 'comment', 'vote', 'cookie_string',
        'recaptcha_challenge_field', 'recaptcha_response_field']
    template_name = 'add_vote.html'
    form_class = VoteModelForm

    def dispatch(self, request, *args, **kwargs):
        topic_slug = self.kwargs.get('slug', '')
        topic = Topic.objects.filter(topic_slug=topic_slug)
        self.initial['cookie_string'] = request.session.session_key
        if topic:
            self.initial.update({
                'topic_title' : topic[0].topic_title,
                'topic_slug' : topic[0].topic_slug,
                'recaptcha_public_key' : settings.PUBLIC_KEY,
                'comment' : request.POST.get('comment', '')})
        else:
            self.initial.update({
                'topic_title' : '',
                'topic_slug' : '',
                'recaptcha_public_key' : settings.PUBLIC_KEY,
                'comment' : ''})

        return super(VoteFormView, self).dispatch(request, *args, **kwargs)

    def get_form_kwargs(self):
        kwargs = super(VoteFormView, self).get_form_kwargs()
        if not settings.TESTING:
            kwargs['request'] = self.request
        return kwargs

    def get_context_data(self, **kwargs):
        context = super(VoteFormView, self).get_context_data(**kwargs)
        cursor = connection.cursor()
        cursor.execute('''SELECT id, counted, cookie_string, comment, vote,
            date_created, votes_negative, votes_positive FROM list_votes(%s)''',
            [self.initial.get('topic_slug',''),])
        context['topic_votes'] = cursor.fetchall()
        ########## debugger on ##########
        #~ from pudb import set_trace; set_trace()
        return context

    def form_valid(self, form):
        form.store()

        if form.errors:
            return self.form_invalid(form)
        else:
            self.success_url = '/vote/%s' % self.initial.get('topic_slug','')
            return super(VoteFormView, self).form_valid(form)
