from django.conf.urls import patterns, include, url
from badmeter.views import TopicFormView, HomeTemplateView, VoteFormView

from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'myproject.views.home', name='home'),
    # url(r'^blog/', include('blog.urls')),

    url(r'^$', HomeTemplateView.as_view(), name='home_root'),
    url(r'^index/$', HomeTemplateView.as_view(), name='home'),
    url(r'^home/$', HomeTemplateView.as_view(), name='home_main'),
    url(r'^search/', 'badmeter.views.search'),
    url(r'^topic/', TopicFormView.as_view(), name='topic-form-view'),
    url(r'^vote/(?P<slug>[-\w]+)/', VoteFormView.as_view(), name='vote-form-view'),
    url(r'^admin/', include(admin.site.urls)),
)
