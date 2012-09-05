# ActiveRecord DB Diagrams
# Configuration parameters can be changed by writing a file named config/modal_diagrams.yml

module ModalDiagrams

  # Field type abbreviations
  TYPE = {
    :date=>'d',
    :datetime=>'dt',
    :timestamp=>'ts',
    :boolean=>'b',
    :integer=>'i',
    :string=>'s',
    :text=>'tx',
    :float=>'f',
    :decimal=>'d',
    :geometry=>'g'
  }

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

      models = dbmodels

      models.each do |cls|
        if cls.respond_to?(:reflect_on_all_associations) && ActiveRecord::Base.connection.table_exists?(cls.table_name)
          # Note: Don't use content_columns ignores columns ending with _id which I use for enum fields
          columns = cls.columns.reject { |c| c.primary || c.name =~ /(_count)$/ || c.name == cls.inheritance_column || c.name =~ /^(created_at|updated_at)$/ }.map{|c| "#{c.name} : #{TYPE[c.type]}"}
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
                head = poly ? "obox" : "tee" # mark the end with the foreign key
              when :one_to_many
                tail = "none"
                head = poly ? "odot" : "dot"
              when :many_to_many
                tail = "dot"
                head = "dot"
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
        sti_classes.each do |sti_class|
          cls = sti_class.base_class
          if cls.respond_to?(:cluster)
            cluster = cls.cluster.to_s
          else
            cluster = ""
          end
          if cfg.sti_fields && sti_class.respond_to?(:fields_info) && sti_class.fields_info!=:omitted
            columns = sti_class.fields_info.map{|c| "#{c.name} : #{TYPE[c.type]}"}
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
      mkdir_p fn.dirname
      File.open(fn,'w') do |f|
        add_diagram_header f
        cluster_id = 0
        all_classes = []
        classes.keys.each do |cluster|
          next if cluster.in? cfg.clusters_not_shown_on_main_diagram
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

    # return ActiveRecord classes corresponding to tables, without STI derived classes, but including indirectly
    # derived classes that do have their own tables (to achieve this we use the convention that in such cases
    # the base class, directly derived from ActiveRecord::Base has a nil table_name)
    def dbmodels
      models = Dir.glob(File.join(Rails.root,"app/models/**/*.rb"))\
                 .map{|f| File.basename(f).chomp(".rb").camelize.constantize}\
                 .select{|c| has_table(c)}\
                 .reject{|c| has_table(c.superclass)}
      models += ActiveRecord::Base.send(:subclasses).reject{|c| c.name.starts_with?('CGI::') || !has_table(c) || has_table(c.superclass)}
      models.uniq
    end

    def sti_classes
      models = Dir.glob(File.join(Rails.root,"app/models/**/*.rb"))\
                 .map{|f| File.basename(f).chomp(".rb").camelize.constantize}\
                 .select{|c| has_table(c) && c.base_class!=c}
      models += ActiveRecord::Base.send(:subclasses).reject{|c| c.name.starts_with?('CGI::') || !has_table(c)}.select{|c| has_table(c) && c.base_class!=c}
      models.uniq
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

  end

end