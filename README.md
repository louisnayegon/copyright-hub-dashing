Check out http://shopify.github.com/dashing for more information.

Edit the github.yml file with your github login name and oauth password

## Runing the service

If building on Ubuntu make sure dependencies are installed with the following
commands.

```bash
sudo apt-get install ruby`ruby -e 'puts RUBY_VERSION[/\d+\.\d+/]'`-dev
sudo apt-get install gcc
sudo apt-get install make
sudo apt-get install libcurl4-openssl-dev
sudo apt-get install build-essential
```

Then the service can be run

```bash
bundle install --path .bundle
bundle exec dashing start
```

You should be able to access the dashboard at

http://localhost:3030/github-status

## Update lock file

```bash
bundle lock --update
```
