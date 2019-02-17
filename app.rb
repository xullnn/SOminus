require 'sinatra'
require 'tilt/erubis'
require 'yaml'

if development?
  require 'pry'
  require 'sinatra/reloader'
end
