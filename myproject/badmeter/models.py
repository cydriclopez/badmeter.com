
from django.db import models, connection
from .misc import print_info

# Business rules are implemented in postgresql server-side stored
# function for efficiency. This elliminates back-and-forth traffic
# between django orm and postgresql.
#
# PostgreSQL server-side business rules implemented:
#    1. 1-vote-per-day rule
#    2. Auto-increment Topic and Cookie tables counters.
#    3. 3-day wait period for 1st time vote on new cookie_string.
#    4. 30-day 100-vote requirement for purging topics.

class CheckModelSave(object):
    """
    CheckModelSave is used to capture returned database message.
    """
    _error_code = 0
    _error_msg = ''

    def __init__(self, rows):
        try:
            for row in rows:
                self._error_code = int(row[0])
                self._error_msg = ''.join([self._error_msg, ' ', row[1]])
        except:
            pass

    @property
    def if_error(self):
        return self._error_code < 0

    @property
    def get_error_code(self):
        return self._error_code

    @property
    def get_error_msg(self):
        return self._error_msg


class Cookie(models.Model):
    """
    Cookie table keeps user unique session cookie id.
    """
    cookie_string = models.CharField(db_index=True, max_length=100)
    #~ Note that Topic & Cookie tables have cyclic foreigh-key dependencies.
    #~ This is addressed by: 'badmeter.Topic', related_name='topic_cookies', null=True
    topic = models.ForeignKey('badmeter.Topic', related_name='topic_cookies',
        null=True, blank=True, on_delete=models.CASCADE)
    votes_positive = models.IntegerField(null=True)
    votes_negative = models.IntegerField(null=True)
    date_created = models.DateTimeField(auto_now_add=True)
    date_updated = models.DateTimeField(auto_now_add=True)

    def __unicode__(self):
        return u'%s' % (self.cookie_string)


class Topic(models.Model):
    """
    Topic table saves user created topics.
    """
    topic_title = models.CharField(db_index=True, max_length=100)
    topic_slug = models.SlugField(db_index=True, max_length=100)
    badmeter = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    votes_positive = models.IntegerField(null=True)
    votes_negative = models.IntegerField(null=True)
    #~ Note that Topic & Cookie tables have cyclic foreigh-key dependencies.
    #~ This is addressed by: related_name='cookie_topics', null=True
    cookie = models.ForeignKey(Cookie, related_name='cookie_topics',
        null=True, blank=True, on_delete=models.CASCADE)
    date_created = models.DateTimeField(auto_now_add=True)
    date_updated = models.DateTimeField(auto_now_add=True)

    # Container for returned database message (class CheckModelSave()).
    check_model_save = None

    def __unicode__(self):
        return u'%s -- %s' % (self.topic_title, self.topic_slug)

    def save(self, *args, **kwargs):
        #~ By-pass orm for custom save using a database stored function.
        #~ This way the call is a one-way trip to the server. Using orm
        #~ is clumsy in this way. Reference to cookie_string in table
        #~ Cookie is saved in both Topic and Cookie save. Vote counters are
        #~ also set to zero in the add_topic() plgsql stored function.

        arg = args[1]
        cursor = connection.cursor()
        cursor.execute(
            'SELECT return_id, status_message FROM add_topic(%s, %s, %s)', [
                arg['topic_title'],
                arg['topic_slug'],
                arg['cookie_string']
            ]
        )

        # Save database returned message for debug purposes.
        self.check_model_save = CheckModelSave(cursor.fetchall())


class Vote(models.Model):
    """
    Vote table saves user created votes. Business rules are implemented on
    postgresql server-side stored function for efficiency. This elliminates
    back-and-forth traffic between django orm and postgresql.
    """
    topic = models.ForeignKey(Topic)
    cookie = models.ForeignKey(Cookie)
    comment = models.CharField(max_length=400)
    vote = models.NullBooleanField(default=None)
    counted = models.NullBooleanField(default=None)
    date_created = models.DateTimeField(db_index=True, auto_now_add=True)

    # Container for returned database message (class CheckModelSave()).
    check_model_save = None

    def __unicode__(self):
        return u'%s -- %s' % (self.topic, self.topic.topic_slug)

    def get_absolute_url(self):
        return reverse('vote-form-view', kwargs={'slug': self.topic.topic_slug})

    def save(self, *args, **kwargs):
        #~ By-pass orm for custom save using a database stored function.
        #~ This way the call is a one-way trip to the server. Using orm
        #~ is clumsy in this way. The cookie_string is saved in both Vote.save()
        #~ and Cookie.save() for unique cookie_string. Vote counters are
        #~ also incremented in both Topic.save() and Cookie.save() tables.

        arg = args[1]
        cursor = connection.cursor()
        cursor.execute(
            'SELECT return_id, status_message FROM add_vote(%s, %s, %s, %s)', [
                arg['topic_slug'],
                arg['cookie_string'],
                arg['comment'],
                arg['vote']
            ]
        )

        # Save database returned message for debug purposes.
        self.check_model_save = CheckModelSave(cursor.fetchall())
