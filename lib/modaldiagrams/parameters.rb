module ModalDiagrams

  def self.parameters
    @settings ||= Settings[
      # Default values
      :include_all_models => false,              # include models defined in plugins
      :include_dynamic_models => false,          # include models defined dynamically (not in model files)
      :max_attributes => 24,                     # maximum number of attributes shown in a class (table)
      :clusters_not_shown_on_main_diagram => [], # clusters not shown in the main diagram
      :show_external => true,                    # show associations to classes from other clusters in cluster diagrams
      :show_cluster_boxes => false,              # display cluster names capitalized inside a box (good for dot; bad for neato)
      :show_multiple => true,                    # show multiple associations between two classes
      :show_sti => true,                         # show STI classes
      :sti_fields => true,                       # show fields of STI classes where declared if using modalfields
      :unified_polymorphic => false,             # unify the circled end of polymorphic associations
      :no_association_labels=>false,             # don't show association labels
      :output_tools => %w{dot fdp neato},        # graphviz styles (tools) used whe generating output (ps/png/pdf)
      :type_abbreviations => {                   # abbreviations used for field types
        :date=>'d',
        :datetime=>'dt',
        :timestamp=>'ts',
        :boolean=>'b',
        :integer=>'i',
        :string=>'s',
        :text=>'tx',
        :float=>'f',
        :decimal=>'d',
        :geometry=>'g',
        :spatial=>'g'
      },
      :arrow_heads => {
        :multiple => 'dot',       # zero or more (crowodot for standard ERD notation)
        :single   => 'tee',       # zero or one  (teeodot for standard ERD notation),
        :poly_multiple => 'odot', # polymorphic zero or more
        :poly_single => 'obox'    # polymorphic zero or more
      }
    ].merge Settings.load(Rails.root.join('config','modal_diagrams.yml'))
  end

end