Push middleware
===============

To make incoming calls possible, you need to setup your own middleware. We use Asterisk servers as our PBX. The asterisk asks the middleware to push a message to the app. The app will ask the library to register an account. The app will then respond to the middleware when that is successful. The Asterisk will then try to connect to the app. More info on the middleware, we will publish the code we use asap on [we will publish the code we use asap on this repo](https://github.com/VoIPGRID/vialer-incoming-call-notifier).
