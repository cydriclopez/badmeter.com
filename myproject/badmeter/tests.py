
from datetime import datetime, date
from django.test import TestCase
from django.test.client import Client
from django.db import models, connection
from django.utils.text import slugify
from .misc import (print_info, strip_extra_spaces, ageinyears,
    ageindays_string, hash_md5_random_hexdigest)
from .models import Topic, Vote, Cookie
from .forms import TopicModelForm, VoteModelForm


class Test_misc_functions(TestCase):
    """
    Test miscellaneous functions.
    """
    def test_strip_extra_spaces(self):
        string_before = '    the     quick       brown     fox      '
        string_after = 'the quick brown fox'
        self.assertEqual(strip_extra_spaces(string_before), string_after)

    def test_ageinyears(self):
        born = date(2001, 11, 16)
        today = date.today()
        age = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        self.assertEqual(ageinyears(born), age)

    def test_ageindays_string(self):
        born_datetime = datetime(2001, 11, 16)
        datetime_now = datetime.now()
        age_str = ''.join(str(datetime.now()-born_datetime).split('.')[:1])
        self.assertEqual(ageindays_string(born_datetime), age_str)


class Test_index_page(TestCase):
    """
    Check to make sure parts of home page are accessible.
    """
    def test_index_page(self):
        client = Client()
        response = client.get('/home/')
        self.assertEqual(response.status_code, 200)

    def test_index_home_section(self):
        client = Client()
        response = client.get('/home/#home_section/')
        self.assertEqual(response.status_code, 200)

    def test_index_features_section(self):
        client = Client()
        response = client.get('/index/#features_section/')
        self.assertEqual(response.status_code, 200)

    def test_index_howitworks_section(self):
        client = Client()
        response = client.get('/index/#howitworks_section/')
        self.assertEqual(response.status_code, 200)

    def test_index_about_section(self):
        client = Client()
        response = client.get('/index/#about_section/')
        self.assertEqual(response.status_code, 200)

    def test_index_contact_section(self):
        client = Client()
        response = client.get('/index/#contact_section/')
        self.assertEqual(response.status_code, 200)


class Test_main(TestCase):

    @classmethod
    def setUpClass(cls):
        """
        Create plpgsql stored procedures in the test database
        The file all.sql is the compilation of all stored procedures used.
        It is created by the following:

        cd into folder myproject/badmeter and then run:
        cat sql/* > all.sql
        """
        f = open('/home/user1/Projects/badmeter.com/myproject/badmeter/all.sql')
        sql = f.read()
        f.close()
        cursor = connection.cursor()
        cursor.execute(sql)
        cursor.connection.commit()

    # Create a topic
    def add_topic_test(self, topic_title,
        topic_slug, cookie_string):

        topic = Topic()
        topic.save(topic, {
            'topic_title' : topic_title,
            'topic_slug' : topic_slug,
            'cookie_string' : cookie_string
        })
        self.assertTrue(topic)

    # Add a vote
    def add_vote_test(self, topic_slug,
        cookie_string, comment, opinion):

        vote = Vote()
        vote.save(vote, {
            'topic_slug' : topic_slug,
            'cookie_string' : cookie_string,
            'comment' : comment,
            'vote' : opinion
        })
        self.assertTrue(vote)

    def test_main_models(self):
        """
        Test save & retrieve of models.
        """
        topic_title = 'The quick brown fox jumped over the lazy dog'
        topic_slug = slugify(unicode(topic_title))
        cookie_string = hash_md5_random_hexdigest()

        self.add_topic_test(
            topic_title,
            topic_slug,
            cookie_string
        )

        comment = 'Just a silly comment.'
        opinion = 'true'

        self.add_vote_test(
            topic_slug,
            cookie_string,
            comment,
            opinion
        )

        # Search topic prefix test
        topic = Topic.objects.filter(topic_title__istartswith='the quick brown').order_by('topic_title')
        self.assertTrue(topic)
        self.assertEqual(topic_slug, topic[0].topic_slug)
        self.assertEqual(topic_title, topic[0].topic_title)

        # Search topic slug test
        topic = Topic.objects.filter(topic_slug=topic_slug)
        self.assertTrue(topic)
        self.assertEqual(topic_slug, topic[0].topic_slug)
        self.assertEqual(topic_title, topic[0].topic_title)

        # Search vote test
        vote = Vote.objects.filter(topic__topic_slug=topic_slug)
        self.assertTrue(vote)
        self.assertEqual(vote[0].comment, comment)
        self.assertEqual(vote[0].vote, (opinion=='true'))

        # Search cookie test
        cookie = Cookie.objects.filter(cookie_string=cookie_string, topic__topic_slug=topic_slug)
        self.assertTrue(cookie)
        self.assertEqual(cookie[0].cookie_string, cookie_string)

    def test_model_forms(self):
        """
        Test entry, save & retrieve using modelforms.
        """
        recaptcha_challenge_field = hash_md5_random_hexdigest()
        recaptcha_response_field = hash_md5_random_hexdigest()
        topic_title = 'The slow purple bat flew over the fast snail'
        topic_slug = slugify(unicode(topic_title))

        data = {
            'recaptcha_challenge_field': recaptcha_challenge_field,
            'recaptcha_response_field': recaptcha_response_field
        }

        # Simulate error: missing 'topic_title' entry.
        topic_model_form = TopicModelForm(data)
        self.assertTrue(topic_model_form.is_bound)
        self.assertFalse(topic_model_form.is_valid())
        self.assertTrue(topic_model_form.errors)

        # Add 'topic_title' to complete entry.
        data['topic_title'] = topic_title

        topic_model_form = TopicModelForm(data)
        self.assertTrue(topic_model_form.is_bound)
        self.assertTrue(topic_model_form.is_valid())
        self.assertFalse(topic_model_form.errors)

        # Use form.store() to save object.
        topic_model_form.store()

        # Search topic prefix test
        topic = Topic.objects.filter(topic_title__istartswith='the slow purple bat').order_by('topic_title')
        self.assertTrue(topic)
        self.assertEqual(topic_slug, topic[0].topic_slug)
        self.assertEqual(topic_title, topic[0].topic_title)

        # Search topic slug test
        topic = Topic.objects.filter(topic_slug=topic_slug)
        self.assertTrue(topic)
        self.assertEqual(topic_slug, topic[0].topic_slug)
        self.assertEqual(topic_title, topic[0].topic_title)

        comment = 'Just a silly comment.'
        data = {
            'topic_slug': topic_slug,
            'recaptcha_challenge_field': recaptcha_challenge_field,
            'recaptcha_response_field': recaptcha_response_field,
            'comment': comment
        }

        # Simulate error: missing 'vote' entry.
        vote_model_form = VoteModelForm(data)
        self.assertTrue(vote_model_form.is_bound)
        self.assertFalse(vote_model_form.is_valid())
        self.assertTrue(vote_model_form.errors)

        # Add 'vote' to complete entry.
        opinion = 'false'
        data['vote'] = opinion

        vote_model_form = VoteModelForm(data)
        self.assertTrue(vote_model_form.is_bound)
        self.assertTrue(vote_model_form.is_valid())
        self.assertFalse(vote_model_form.errors)

        # Use form.store() to save object.
        vote_model_form.store()

        # Search vote test
        vote = Vote.objects.filter(topic__topic_slug=topic_slug)
        self.assertTrue(vote)
        self.assertEqual(vote[0].comment, comment)
        self.assertEqual(vote[0].vote, (opinion=='true'))

    def test_views(self):
        """
        Test entry, save & retrieve using views.
        """
        topic_title = 'Lazy dog crawled under the rug in my living room.'
        topic_slug = slugify(unicode(topic_title))

        # Dummy entries. Recaptcha check is disabled in test.
        recaptcha_challenge_field = hash_md5_random_hexdigest()
        recaptcha_response_field = hash_md5_random_hexdigest()

        client = Client()

        # Test add topic using view TopicFormView thru urlconf.
        response = client.post('/topic/', {
            'topic_title': topic_title,
            'topic_slug': topic_slug,
            'recaptcha_challenge_field': recaptcha_challenge_field,
            'recaptcha_response_field': recaptcha_response_field
        })
        self.assertEqual(response.status_code, 302)

        # Test retrieve just added topic
        url = '/vote/%s/' % topic_slug
        response = client.get(url)
        self.assertContains(response, topic_title, status_code=200)
        self.assertTemplateUsed(response, template_name='add_vote.html')
        self.assertTemplateUsed(response, template_name='base.html')
        self.assertTemplateUsed(response, template_name='stats_table.html')
        self.assertTemplateUsed(response, template_name='google_gauge.html')

        # Test voting to the topic using view VoteFormView thru urlconf.
        comment = 'bunch of malarky'
        response = client.post(url, {
            'topic_slug': topic_slug,
            'recaptcha_challenge_field': recaptcha_challenge_field,
            'recaptcha_response_field': recaptcha_response_field,
            'comment': comment,
            'vote': 'true'
        })
        self.assertEqual(response.status_code, 302)

        # Test retrieve just added vote
        response = client.get(url)
        #~ print_info('response.content')
        #~ print_info(response.content)
        self.assertContains(response, comment, status_code=200)
        self.assertTemplateUsed(response, template_name='add_vote.html')
        self.assertTemplateUsed(response, template_name='base.html')
        self.assertTemplateUsed(response, template_name='stats_table.html')
        self.assertTemplateUsed(response, template_name='google_gauge.html')
