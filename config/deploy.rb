#  set :bundle_gemfile,  "Gemfile"
#  set :bundle_dir,      File.join(fetch(:shared_path), 'bundle')
#  set :bundle_flags,    "--deployment --quiet"
#  set :bundle_without,  [:development, :test]
#  set :bundle_cmd,      "bundle" # e.g. "/opt/ruby/bin/bundle"
#  set :bundle_roles,    {:except => {:no_release => true}} # e.g. [:app, :batch]
set :default_environment, {
 'LANG'   => "en_US.UTF-8",
 'LC_ALL' => "en_US.UTF-8"
}
set :default_shell, "bash -l"

require "bundler/capistrano"
require 'sidekiq/capistrano'
load 'deploy/assets'

set :application, "vk"

set :keys_master_file, "/home/victorykit/keys_and_settings.sh"

set :use_sudo, false
default_run_options[:pty] = true

set :keep_releases, 10
after "deploy:update", "deploy:cleanup"

# Repo info
set :repository, "git@github.com:ginkgomzd/victorykit.git"
set :scm, "git"
ssh_options[:forward_agent] = true
set :branch, "demand_progress"
set :deploy_via, :remote_cache
set :copy_exclude, [ '.git' ]

# Deploy target info
set :deploy_to, "/home/victorykit/vk"
role :web, "flask.ginkgostreet.com"
role :app, "flask.ginkgostreet.com"
role :db,  "flask.ginkgostreet.com", :primary => true

# Sidekiq
set(:sidekiq_cmd) { "#{current_path}/bin/vk_run.sh sidekiq" }
set(:sidekiqctl_cmd) { "#{current_path}/bin/vk_run.sh sidekiqctl" }
set(:sidekiq_timeout) { 10 }
set(:sidekiq_role) { :app }
set(:sidekiq_pid) { "#{current_path}/pids/vk_sidekiq.pid" }
set(:sidekiq_log) { "#{current_path}/log/vk_sidekiq.log" }
set(:sidekiq_processes) { 1 }


namespace :symlinks do
  desc "[internal] Updates the symlinks to config files (for the just deployed release)."
  task :set_links, :except => { :no_release => true } do
    [
      'database.yml', 'memcached.yml'
    ].each do |file|
      run "if [ -e #{shared_path}/config/#{file} ]; then ln -nfs #{shared_path}/config/#{file} #{release_path}/config/#{file}; fi"
    end
    [
      'log', 'pids'
    ].each do |file|
      run "if [ -e #{shared_path}/#{file} ]; then ln -nfs #{shared_path}/#{file} #{release_path}/#{file}; fi"
    end
    #run "ln -nfs #{shared_path}/assets #{release_path}/public/assets"
  end
  after "deploy:finalize_update", "symlinks:set_links"
end

namespace :keys_and_settings do
  desc "Ensure that the keys and settings file is in the shared dir."
  task :ensure_file do
    run "if [ ! -f #{shared_path}/config/keys_and_settings.sh && -f #{keys_master_file} ]; cp #{keys_master_file} #{shared_path}/config/keys_and_settings.sh; fi"
  end
  after "deploy:finalize_update", "keys_and_settings:ensure_file"
end

set :rails_env, "production"
set :unicorn_binary, "#{shared_path}/bundle/ruby/2.0.0/bin/unicorn"
set :unicorn_config, "#{current_path}/config/unicorn-prod.rb"
set :unicorn_pid,    "#{shared_path}/pids/vk_app_master.pid"


namespace :deploy do

  namespace :unicorn do
    desc "Start unicorn (when they're not running)"
    task :start, :roles => :app, :except => { :no_release => true } do 
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh #{unicorn_binary} -c #{unicorn_config} -E #{rails_env} -D"
    end

    desc "Stops unicorn immediately w/o waiting for active requests to complete"
    task :hard_stop, :roles => :app, :except => { :no_release => true } do 
      run "#{try_sudo} kill `cat #{unicorn_pid}`"
    end

    desc "Gracefully stops unicorn"
    task :stop, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} kill -s QUIT `cat #{unicorn_pid}`"
    end

    desc "Gracefully restarts unicorn"
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} kill -s USR2 `cat #{unicorn_pid}`"
    end

    desc "Performs a 'hard_stop' followed by a 'start'"
    task :hard_restart, :roles => :app, :except => { :no_release => true } do
      hard_stop
      start
    end
  end

  namespace :emailer do
    desc "Start emailer (when they're not running)"
    task :start, :roles => :app, :except => { :no_release => true } do 
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh script/vk_emailer.rb start"
    end

    desc "Stops emailer immediately w/o waiting for active requests to complete"
    task :hard_stop, :roles => :app, :except => { :no_release => true } do 
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh script/vk_emailer.rb stop"
    end

    desc "Gracefully stops emailer"
    task :stop, :roles => :app, :except => { :no_release => true } do
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh script/vk_emailer.rb stop"
    end

    desc "Gracefully restarts emailer"
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh script/vk_emailer.rb restart"
    end

    desc "Performs a 'hard_stop' followed by a 'start'"
    task :hard_restart, :roles => :app, :except => { :no_release => true } do
      hard_stop
      start
    end

    desc "Retrive emailer staus"
    task :status, :roles => :app, :except => { :no_release => true } do
      run "cd #{current_path} && #{current_path}/bin/vk_run.sh script/vk_emailer.rb status"
    end
  end


  desc "Start services (when they're not running)"
  task :start, :roles => :app, :except => { :no_release => true } do 
    unicorn.start
    emailer.start
  end

  desc "Stops services immediately w/o waiting for active requests to complete"
  task :hard_stop, :roles => :app, :except => { :no_release => true } do 
    unicorn.hard_stop
    emailer.hard_stop
  end

  desc "Gracefully stops services"
  task :stop, :roles => :app, :except => { :no_release => true } do
    unicorn.stop
    emailer.stop
  end

  desc "Gracefully restarts services"
  task :restart, :roles => :app, :except => { :no_release => true } do
    unicorn.restart
    emailer.restart
end

  desc "Performs a 'hard_stop' followed by a 'start' for all services"
  task :hard_restart, :roles => :app, :except => { :no_release => true } do
    unicorn.hard_stop
    unicorn.start
    emailer.hard_stop
    emailer.start
  end

  task :echo_env do
    run "#{current_path}/bin/vk_env_run.sh env | sort"
  end
end


#
# Might be needed at some point if we get dup
# sidekiq processes on restart...
#
# namespace :sidekiq do
#   desc "Restart sidekiq"
#   task :restart, :roles => :app, :on_no_matching_servers => :continue do
#     run "sudo /usr/bin/monit restart sidekiq"
#   end
# end
