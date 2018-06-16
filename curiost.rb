# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

STDOUT.sync = true

require 'time'
require 'haml'
require 'sinatra'
require 'sinatra/cookies'
require 'raven'
require 'glogin'

require_relative 'version'
require_relative 'objects/dynamo'
require_relative 'objects/owner'

configure do
  Haml::Options.defaults[:format] = :xhtml
  config = {
    'github' => {
      'client_id' => '?',
      'client_secret' => '?',
      'encryption_secret' => ''
    },
    'sentry' => ''
  }
  config = YAML.safe_load(File.open(File.join(File.dirname(__FILE__), 'config.yml'))) unless ENV['RACK_ENV'] == 'test'
  if ENV['RACK_ENV'] != 'test'
    Raven.configure do |c|
      c.dsn = config['sentry']
      c.release = VERSION
    end
  end
  set :dump_errors, true
  set :show_exceptions, true
  set :config, config
  set :logging, true
  set :server_settings, timeout: 25
  set :dynamo, Dynamo.new(config).aws
  set :glogin, GLogin::Auth.new(
    config['github']['client_id'],
    config['github']['client_secret'],
    'https://www.curiost.com/github-callback'
  )
end

before '/*' do
  @locals = {
    ver: VERSION,
    login_link: settings.glogin.login_uri
  }
  cookies[:glogin] = params[:glogin] if params[:glogin]
  if cookies[:glogin]
    begin
      @locals[:user] = GLogin::Cookie::Closed.new(
        cookies[:glogin],
        settings.config['github']['encryption_secret']
      ).to_user
      @locals[:owner] = Owner.new(settings.dynamo, @locals[:user][:login])
    rescue OpenSSL::Cipher::CipherError => _
      @locals.delete(:user)
    end
  end
end

get '/github-callback' do
  cookies[:glogin] = GLogin::Cookie::Open.new(
    settings.glogin.user(params[:code]),
    settings.config['github']['encryption_secret']
  ).to_s
  redirect to('/')
end

get '/logout' do
  cookies.delete(:glogin)
  redirect to('/')
end

get '/hello' do
  redirect '/' if @locals[:user]
  haml :hello, layout: :layout, locals: merged(
    title: '/hello'
  )
end

get '/' do
  redirect '/hello' unless @locals[:user]
  haml :index, layout: :layout, locals: merged(
    title: '/',
    query: params[:q],
    tuples: @locals[:owner].tuples(params[:q].to_s)
  )
end

get '/robots.txt' do
  "User-agent: *\nDisallow: /"
end

get '/version' do
  VERSION
end

get '/e' do
  redirect '/hello' unless @locals[:user]
  haml :entity, layout: :layout, locals: merged(
    title: params[:entity],
    entity: params[:entity],
    history: @locals[:owner].history(params[:entity])
  )
end

get '/add' do
  redirect '/hello' unless @locals[:user]
  haml :add, layout: :layout, locals: merged(
    title: '/add'
  )
end

post '/do-add' do
  redirect '/hello' unless @locals[:user]
  @locals[:owner].add(params[:entity], Time.parse(params[:time]), params[:rel], params[:text])
  redirect '/'
end

not_found do
  status 404
  content_type 'text/html', charset: 'utf-8'
  haml :not_found, layout: :layout, locals: merged(
    title: 'Page not found'
  )
end

error do
  status 503
  e = env['sinatra.error']
  Raven.capture_exception(e)
  haml(
    :error,
    layout: :layout,
    locals: merged(
      title: 'error',
      error: "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    )
  )
end

private

def merged(hash)
  out = @locals.merge(hash)
  out[:local_assigns] = out
  out
end
