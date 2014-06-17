# ActiveRecord DB Diagrams
# Configuration parameters can be changed by writing a file named config/modal_diagrams.yml

require 'modalsettings'
require 'modalsupport'

module ModalDiagrams

  class <<self

    def enable_clusters
      if defined?(::Rails)
        ::ActiveRecord::Base.class_eval do
          def self.cluster(name=nil)
            if name
              @cluster_name = name
            else
              @cluster_name
             end
          end
        end
      end
    end

    def generate(cfg)

      classes = {""=>[]} # assoc cluster name ("" for no cluster) to array of class definitions
      relations = []     # array of relation defitions
      n_m = [] # this is to avoid duplicating n:m relations
      rep = [] # this is to avoid multiple relations between two models
      # and the next is to draw separate diagrams per cluster
      cluster_classes = {} # assoc cluster name to array of class names
      relation_classes = [] # each element is the 2-element array of class names of the corresponding relation in relations

      model_selection_options = {
          :all_models => cfg.include_all_models,
          :dynamic_models => cfg.include_dynamic_models,
          :include_files => false,
          :exclude_models => cfg.exclude_models
      }

      models, excluded_models = dbmodels(model_selection_options.merge(:exclude_sti_models => true))
      excluded_class_names = excluded_models.map(&:name)

      models.each do |cls|
        if cls.respond_to?(:reflect_on_all_associations) && ActiveRecord::Base.connection.table_exists?(cls.table_name)
          # Note: Don't use content_columns ignores columns ending with _id which I use for enum fields
          columns = cls.columns.reject { |c| c.primary || c.name =~ /(_count)$/ || c.name == cls.inheritance_column || c.name =~ /^(created_at|updated_at)$/ }.map{|c| field_spec(cfg, c)}
          columns_to_ignore = cls.reflect_on_all_associations.map{|a|
            cols = []
            if a.macro == :belongs_to
              cols << assoc_foreign_key(a)
              cols << assoc_foreign_type(a) if a.options[:polymorphic]
            end
            cols
          }.flatten.compact.uniq
          columns.reject!{|c| c.split(':').first.strip.in? columns_to_ignore}
          if cfg.sti_fields && cls.respond_to?(:fields_info) && cls.fields_info!=:omitted
            columns.reject!{|c| !c.split(':').first.strip.in? cls.fields_info.map{|c| c.name.to_s}}
          end
          columns = columns.to(cfg.max_attributes) + ['...'] if columns.size > cfg.max_attributes
          # columns.reject! do |cname|
          #   cname.match(/_id\Z/) || cname.match(/_type\Z/)
          # end
          # arrowhead,arrowtail=none, normal, inv, dot, odot, invdot, invodot, tee,
          #      empty, invempty, open(2,3,n), halfopen, diamond, odiamond, box, obox, crow.
          if cls.respond_to?(:cluster)
            cluster = cls.cluster.to_s
            classes[cluster] ||= []
          else
            cluster = ""
          end
          classes[cluster] << %{"#{cls}" [shape=Mrecord, label="{#{cls}|#{columns.join('\\l')}\\l}"]}
          cluster_classes[cluster] ||= []
          cluster_classes[cluster] << cls.to_s
          cls.reflect_on_all_associations.each do |assoc|
            next if assoc.class_name.in?(excluded_class_names)
            target,type = nil,nil
            case assoc.macro
            when :has_many
              unless assoc.options[:through]
                target = assoc.class_name
                type = :one_to_many
                if !cfg.show_multiple && rep.include?([cls.to_s, target.to_s])
                  target = type = nil
                else
                  rep << [cls.to_s,target.to_s]
                end
              end
            when :has_one
              target = assoc.class_name
              type = :one_to_one
            when :has_and_belongs_to_many
              target = assoc.class_name
              type = :many_to_many
              if n_m.include?([target.to_s, cls.to_s])
                target = type = nil
              else
                n_m << [cls.to_s,target.to_s]
              end
            end
            if target
              pk = assoc_foreign_key(assoc)
              # detect specially named associations (usually polymorphi) and label it
              if pk != cls.to_s.underscore+"_id"
                label = pk.to_s
                label = label[0..-4] if label[-3..-1]=='_id'
                if label.size<=15
                  label = "headlabel=#{label}, "
                else
                  label = nil
                end
              else
                label = nil
              end
              # detect polymorphic associations to use a different symbol
              poly = false
              if iassoc =  target.constantize.reflect_on_all_associations.detect{|a| !a.options[:through] && pk==assoc_foreign_key(a)}
                if iassoc.options[:polymorphic]
                  poly = true
                end
              end
              #puts "#{cls} -#{type}-> #{target}"
              case type
              when :one_to_one
                tail = "none"
                head = poly ? cfg.arrow_heads.poly_single : cfg.arrow_heads.single # mark the end with the foreign key
              when :one_to_many
                tail = "none"
                head = poly ? cfg.arrow_heads.poly_multiple : cfg.arrow_heads.multiple
              when :many_to_many
                tail = cfg.arrow_heads.multiple
                head = cfg.arrow_heads.multiple
              end
              samehead = (cfg.unified_polymorphic && label) ? %{, samehead="#{label}"} : ''
              label = nil if cfg.no_association_labels
              relations << %{"#{cls}" -> "#{target}" [arrowtail=#{tail}, arrowhead=#{head}#{samehead} #{label}dir=both]}
              relation_classes << [cls.to_s, target.to_s]
            end
          end
        end
      end

      if cfg.show_sti
        sti_classes, exc = dbmodels(model_selection_options.merge(:exclude_non_sti_models => true))
        sti_classes.each do |sti_class|
          cls = sti_class.base_class
          if cls.respond_to?(:cluster)
            cluster = cls.cluster.to_s
          else
            cluster = ""
          end
          if cfg.sti_fields && sti_class.respond_to?(:fields_info) && sti_class.fields_info!=:omitted
            columns = sti_class.fields_info.map{|c| field_spec(cfg, c)}
            columns = columns.to(cfg.max_attributes) + ['...'] if columns.size > cfg.max_attributes
          else
            columns = nil
          end
          classes[cluster] ||= []
          classes[cluster] << %{"#{sti_class}" [shape=Mrecord, label="{#{sti_class}\\l}"]}
          cluster_classes[cluster] ||= []
          cluster_classes[cluster] << sti_class.to_s
          if columns
            classes[cluster] << %{"#{sti_class}" [shape=Mrecord, label="{#{sti_class}|#{columns.join('\\l')}\\l}"]}
          end
          base_class = sti_class.superclass
          relations << %{"#{base_class}" -> "#{sti_class}" [arrowtail=onormal, arrowhead=none, dir=both]}
          relation_classes << [base_class.to_s, sti_class.to_s]
        end
      end

      fn = Rails.root.join('db/diagrams/diagram.dot')
      FileUtils.mkdir_p fn.dirname
      File.open(fn,'w') do |f|
        add_diagram_header f
        cluster_id = 0
        all_classes = []
        classes.keys.each do |cluster|
          next if cluster.in? cfg.clusters_not_shown_on_main_diagram
          next if cluster_classes[cluster].nil?
          all_classes += cluster_classes[cluster]
          cluster_id += 1
          add_diagram_classes f, classes[cluster], cluster, cluster_id, cfg.show_cluster_boxes
        end
        add_diagram_relations f, relations, relation_classes, all_classes, cfg.show_external
        add_diagram_footer f
      end
      classes.keys.each do |cluster|
        #next if cluster.blank?
        fn = "db/diagrams/diagram_#{cluster.downcase}.dot"
        File.open(fn,'w') do |f|
          add_diagram_header f
          add_diagram_classes f, classes[cluster]
          add_diagram_relations f, relations, relation_classes, cluster_classes[cluster], cfg.show_external
          add_diagram_footer f
        end
      end
      puts "The diagrams have been written to #{fn}"

    end


    private

    # Return the database models
    # Options:
    #   :all_models                # Return also models in plugins, not only in the app (app/models)
    #   :dynamic_models            # Return dynamically defined models too (not defined in a model file)
    #   :exclude_sti_models        # Exclude derived (STI) models
    #   :exclude_non_sti_models    # Exclude top level models
    #   :exclude_models            # Array of models to exclude from the diagrams
    #   :include_files             # Return also the model definition file pathnames (return pairs of [model, file])
    #   :only_app_files            #   But return nil for files not in the app proper
    #   :only_app_tree_files       #   But return nil for files not in the app directory tree (app, vendor...)
    def dbmodels(options={})

      models_dir = 'app/models'
      if Rails.respond_to?(:application)
        model_dirs = Rails.application.paths[models_dir]
      else
        model_dirs = [models_dir]
      end
      models_dir = Rails.root.join(models_dir)
      model_dirs = model_dirs.map{|d| Rails.root.join(d)}

      if options[:all_models]
        # Include also models from plugins
        model_dirs = $:.grep(/\/models\/?\Z/)
      end

      models = []
      files = {}
      model_dirs.each do |base|
        Dir.glob(File.join(base,"*.rb")).each do |fn|
          model = File.basename(fn).chomp(".rb").camelize.constantize
          models << model
          files[model.to_s] = fn
        end
      end
      models = models.sort_by{|m| m.to_s}

      if options[:dynamic_models]
        # Now add dynamically generated models (not having dedicated files)
        # note that subclasses of these models are not added here
        models += ActiveRecord::Base.send(:subclasses)
        models = models.uniq
      end

      models = models.uniq.reject{|model| !has_table?(model)}

      non_sti_models, sti_models = models.partition{|model| model.base_class==model}

      models = []
      excluded_models = []
      if options[:exclude_non_sti_models]
        excluded_models += non_sti_models
      else
        models += non_sti_models
      end
      if options[:exclude_sti_models]
        excluded_models += sti_models
      else
        models += sti_models
      end
      if options[:include_files]
        models = models.map{|model| [model, files[model.to_s]]}
        if options[:only_app_files] || options[:only_app_tree_files]
          if options[:only_app_files]
            suffix = models_dir.to_s
          else
            suffix = Rails.root.to_s
          end
          suffix += '/' unless suffix.ends_with?('/')
          models = models.map{|model, file| [model, file && (file.starts_with?(suffix) ? file : nil)]}
        end
      end
      excluded_models = []
      if options[:exclude_models].present?
        excluded_models = Array(options[:exclude_models]).map{|m| String===m ? m.constantize : m}
        models -= excluded_models
      end
      [models, excluded_models]
    end

    def has_table?(cls)
     (cls != ActiveRecord::Base) && cls.respond_to?(:table_name) && cls.table_name.present?
    end
    def assoc_foreign_key(assoc)
      # Up to ActiveRecord 3.1 we had primary_key_name in AssociationReflection; not it is foreign_key
      assoc.respond_to?(:primary_key_name) ? assoc.primary_key_name : assoc.foreign_key
    end

    def assoc_foreign_type(assoc)
      assoc.respond_to?(:foreign_type) ? assoc.foreign_type : assoc.options[:foreign_key]
    end

    def has_table(cls)
      (cls!=ActiveRecord::Base) && cls.respond_to?(:table_name) && !cls.table_name.blank?
    end

    def add_diagram_header(f)
      f.puts "digraph models_diagram {"
      f.puts "   graph[overlap=false, splines=true]"
      f.puts "   edge[labeldistance=2.5, labelfloat=true, labelfontname=Helvetica, decorate=false, labelangle=-30, fontsize=10, fontcolor=gray35]"
    end

    def add_diagram_classes(f, classes, cluster="", cluster_id=nil, show_cluster_boxes=false)
      if cluster==""
        f.puts classes.join("\n")
      elsif cluster.downcase==cluster || !show_cluster_boxes
        f.puts %<subgraph #{cluster_id} {\n  #{classes.join("\n  ")}\n}>
      else
        f.puts %<subgraph cluster_#{cluster_id} { label="#{cluster}"\n  #{classes.join("\n  ")}\n}>
      end
    end

    def add_diagram_relations(f, relations, relation_classes, inner_classes, show_external)
      relations.each_index do |i|
        relation = relations[i]
        inner_classes = Array(inner_classes)
        is_internal = relation_classes[i].all?{|c| c.in? inner_classes}
        is_external = relation_classes[i].any?{|c| c.in? inner_classes} && !is_internal
        if show_external
          show_relation = is_internal || is_external
          unless is_internal
            relation = relation.sub('arrowtail', 'color="gray", arrowtail')
          end
        else
          show_relation = is_internal
        end
        f.puts relation if show_relation
      end
    end

    def add_diagram_footer(f)
      f.puts "}\n"
    end

    def field_spec(cfg, c)
      type = cfg.type_abbreviations[c.type] || c.type
      "#{c.name} : #{type}"
    end

  end

end
