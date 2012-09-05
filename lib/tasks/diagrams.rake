namespace :db do

  desc "Generate DB diagrams (in dot format)"
  task :diagrams => [:environment] do

    cfg = ModalDiagrams.parameters
    puts "Using parameters:"
    puts cfg.to_yaml + "\n"
    puts "To change the parameters create or edit a file named config/modal_diagrams.yml"

    ModalDiagrams.generate cfg

  end

end
