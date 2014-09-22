
from django import forms
from django.utils.text import slugify
from django.utils.safestring import mark_safe
from django.contrib import messages
from recaptcha.client import captcha
from .models import Topic, Vote
from .misc import print_info, strip_extra_spaces, hash_md5_random_hexdigest
from myproject import settings
import os
import hashlib


class TopicModelForm(forms.ModelForm):
    recaptcha_challenge_field = forms.CharField(max_length=500)
    recaptcha_response_field = forms.CharField(max_length=100)

    class Meta:
        model = Topic
        fields = ['topic_title',]

    def __init__(self, *args, **kwargs):
        #~ Grab request object passed by the view.get_form_kwargs method.
        #~ It is needed for self.request.META.get('REMOTE_ADDR')
        #~ used in captcha.submit().
        if not settings.TESTING:
            self.request = kwargs.pop('request')
        super(TopicModelForm, self).__init__(*args, **kwargs)

    def clean(self):
        cleaned_data = super(TopicModelForm, self).clean()
        cleaned_data['topic_title'] = strip_extra_spaces(cleaned_data.get('topic_title'))
        cleaned_data['topic_slug'] = slugify(unicode(cleaned_data['topic_title']))
        cleaned_data['public_key'] = mark_safe(settings.PUBLIC_KEY)

        ########## debugger on ##########
        #~ from pudb import set_trace; set_trace()

        if not settings.TESTING:
            challenge_field = cleaned_data.get('recaptcha_challenge_field')
            response_field = cleaned_data.get('recaptcha_response_field')
            remote_address = self.request.META.get('REMOTE_ADDR')
            captcha_ok = (challenge_field and response_field and remote_address)

            if captcha_ok:
                # Call google's recaptcha server and check for proper entries.
                response = captcha.submit(challenge_field, response_field, settings.PRIVATE_KEY, remote_address)

            if not (captcha_ok and response.is_valid):
                self._errors['recaptcha_response_field'] = mark_safe(''.join(['<ul class="errorlist"><li>',
                    'Recaptcha is required entry.</li></ul>']))

                messages.set_level(self.request, messages.DEBUG)
                messages.info(self.request, self._errors['recaptcha_response_field'])

        return cleaned_data

    def store(self, *args, **kwargs):
        """
        Custom save object by calling the object.save function.
        Creating this custom save function is far easier than overriding forms.ModelForm.save().
        store() is unemcumbered by underlying code implementation of save().
        """
        if settings.TESTING:
            cookie_string = hash_md5_random_hexdigest()
        else:
            cookie_string = self.request.session.session_key

        if not self._errors:
            topic = self.Meta.model()
            topic.save(topic, {
                'topic_title' : self.cleaned_data.get('topic_title'),
                'topic_slug' : self.cleaned_data.get('topic_slug'),
                'cookie_string' : cookie_string})

            if topic.check_model_save and topic.check_model_save.if_error:
                self._errors['cookie_string'] = mark_safe(''.join(['<ul class="errorlist"><li>',
                ''.join(self._errors.get('cookie_string', '')), ' ',
                topic.check_model_save.get_error_msg, '</li></ul>']))

                if not settings.TESTING:
                    messages.set_level(self.request, messages.DEBUG)
                    messages.info(self.request, self._errors['cookie_string'])


class VoteModelForm(forms.ModelForm):
    topic_slug = forms.SlugField(max_length=100)
    recaptcha_challenge_field = forms.CharField(max_length=800)
    recaptcha_response_field = forms.CharField(max_length=100)

    #~ vote here is CharField while the model's is BooleanField.
    #~ Convertion is done in the server-side save function call.
    vote = forms.CharField(max_length=10)

    class Meta:
        model = Vote
        fields = ['comment',]

    def __init__(self, *args, **kwargs):
        #~ Grab request object passed by the view.get_form_kwargs method.
        #~ It is needed for self.request.META.get('REMOTE_ADDR')
        #~ used in captcha.submit().
        if not settings.TESTING:
            self.request = kwargs.pop('request')
        super(VoteModelForm, self).__init__(*args, **kwargs)

    def clean(self):
        cleaned_data = super(VoteModelForm, self).clean()

        if not settings.TESTING:
            challenge_field = cleaned_data.get('recaptcha_challenge_field')
            response_field = cleaned_data.get('recaptcha_response_field')
            remote_address = self.request.META.get('REMOTE_ADDR')
            captcha_ok = (challenge_field and response_field and remote_address)

            if captcha_ok:
                response = captcha.submit(challenge_field, response_field, settings.PRIVATE_KEY, remote_address)

            if not (captcha_ok and response.is_valid):
                self._errors['recaptcha_response_field'] = mark_safe(''.join(['<ul class="errorlist"><li>',
                    'Recaptcha is required entry.</li></ul>']))

                messages.set_level(self.request, messages.DEBUG)
                messages.info(self.request, self._errors['recaptcha_response_field'])

        return cleaned_data

    def store(self, *args, **kwargs):
        """
        Custom save object by calling the object.save function.
        Creating this custom save function is far easier than overriding forms.ModelForm.save().
        store() is unemcumbered by underlying code implementation of save().
        """
        if settings.TESTING:
            cookie_string = hash_md5_random_hexdigest()
        else:
            cookie_string = self.request.session.session_key

        if not self._errors:
            vote = self.Meta.model()
            vote.save(vote, {
                'topic_slug' : self.cleaned_data.get('topic_slug'),
                'cookie_string' : cookie_string,
                'comment' : self.cleaned_data.get('comment'),
                'vote' : self.cleaned_data.get('vote')})

            #~ Capture returned error message from stored function.
            if vote.check_model_save and vote.check_model_save.if_error:
                self._errors['cookie_string'] = mark_safe(''.join(['<ul class="errorlist"><li>',
                ''.join(self._errors.get('cookie_string', '')), ' ',
                vote.check_model_save.get_error_msg, '</li></ul>']))

                if not settings.TESTING:
                    messages.set_level(self.request, messages.DEBUG)
                    messages.info(self.request, self._errors['cookie_string'])
