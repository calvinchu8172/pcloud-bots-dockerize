Chef::Log.info("Running deploy/before_migrate.rb...")

execute "bundle install" do
  cwd release_path
  command "bundle install"
end
