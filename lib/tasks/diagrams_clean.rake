namespace :db do
  namespace :diagrams do

    desc "Clean all db:diagrams generated fiels"
    task :clean => 'environment' do
      diagrams_dir = Rails.root.join("db/diagrams")
      rm_rf diagrams_dir if File.exists?(diagrams_dir)
    end

  end
end
