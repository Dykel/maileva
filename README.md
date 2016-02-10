# Maileva API #

This gem allows you to send postal mails through the **Maileva** system (of La Poste).

## Installation ##

Put this in your `Gemfile`:

    gem 'maileva'

To include all the necessary classes, do:

    require 'maileva'

## Configuration ##

Use `Maileva.config` to configure the default settings of the API like your
Maileva credentials. Example:

    Maileva.config.ftp_login = "my_login"

The available configuration variables are:

 * `files_root`: (`Pathname`, not `String`!) A directory where temporary PDF files
   to send will be stored;
 * `ftp_login`: (`String`) Your Maileva FTP login;
 * `ftp_password`: (`String`) Your Maileva FTP password;
 * `client_id`: (`String`) Your Maileva client ID;
 * `confirmation_threshold`: (Integer, optional) The maximum number of files which
   can be sent without confirmation. Default: 100.

### Setting rules ###

