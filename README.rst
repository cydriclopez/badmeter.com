
Welcome to the badmeter!
============================
**...where you can anonymously vote if something is bad or good!**

This is the home of the badmeter which can help us anonymously rate
anything and everything under the sun. You will notice that in this
website there is absolutely **NO** link to a login & password entry.

Features
--------
Your identity remains absolutely anonymous, at least from our point
of view. We could not care less about your IP address, personal
identity, email address, or social media accounts. All we need is a
session cookie stored in your computer. You can always delete this
cookie. Vote throttling encourages users to keep their session cookie.

Vote throttling: You, with your unique session cookie, are allowed
1 vote per day per topic. Your first 2 votes on a topic will not be
counted. On your 3rd vote all your votes on just this topic will
start to count immediately, including the 2 previous votes. If you
delete and obtain a new session cookie, you will have to go through
this requirement again for the topics you have already voted on.
You can vote on many topics per day.

Topic purging: At anytime when a topic has less than 100 votes
within the past 30 days days then it is deleted. It does not matter
how long the topic has been around. When it becomes a stale topic,
with no one interested in it, then it is deleted.

About
-----
There is a dearth of websites that allow anonymous comments. The
ideal situation is that there should be a place in the internet
where anyone can say anything about anyone or anything, with no
holds barred but subject to constraints of server storage and
bandwidth. This site is a humble simplistic attempt at creating
such a place.

The word Bad can range in meaning from just plain bad, as in NOT
good or terrible, to cool "bad", as in good actually. Here in
this website we try to rate where in this range a particular topic
is, based on the number of negative and positive votes. Hence the
name badmeter. This badmeter should be taken at the least with
humor or at the most "with a grain of salt."  We hope to see you
here often.

PostgreSQL
----------
This project uses the PostgreSQL database. The folder
myproject/badmeter/sql contains all pgsql code used in the project.
Django ORM queries are used in the project but for saving to the
database stored-procedre calls are used.

The Cookie table keeps the voters session id's. The Topic table
keeps the various topics created by the voters. The Vote table
keeps record of the votes by voters on various topics.

The usual approach to this simple project is to make a
many-to-many relationship between the tables Cookie and Topic
via a relationship table Vote.

My inititial approach was exactly this. The badmeter.models.Vote.save()
contained logic to increment counters and implement the business
logic. The back-and-forth between Django ORM and PostgreSQL quickly
became a kludge. I then chose to implement this using stored
procedures in pgsql.

This was a good little trivial project that even presented a
little drama in the form a cyclic dependency between the tables
Vote and Cookie. A quick trip into the Django docs resolved it.

Testing
-------
The classmethod badmeter.tests.Test_main.setUpClass() uses
the file myproject/badmeter/all.sql which is created using
the command:
|  cd myproject/badmeter
|  cat sql/* > all.sql

all.sql is a compilation of all stored procedures used in
the project and in the testing process.

For testing to work make sure the login/password account
into PostgreSQL has the role right to create a database:
|  postgres=# ALTER USER username CREATEDB;

Crontab
-------
Run 'crontab -e' and add the following lines:
|  # Run every midnight a pgsql stored procedre.
|  0 0 * * * psql -d database_name -U username -c "select purge_scan()"

But for this to work you have to create a PostgreSQL password file
~/.pgpass with the following contents:
|  #hostname:port:database:username:password
|  *:5432:database_name:username:password_text

<http://www.badmeter.com>
