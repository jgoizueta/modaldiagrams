module ModalDiagrams

  def self.parameters
    @settings ||= Settings[
      # Default values
      :max_attributes => 24,                     # maximum number of attributes shown in a class (table)
      :clusters_not_shown_on_main_diagram => [], # clusters not shown in the main diagram
      :show_external => true,                    # show associations to classes from other clusters in cluster diagrams
      :show_cluster_boxes => false,              # display cluster names capitalized inside a box (good for dot; bad for neato)
      :show_multiple => true,                    # show multiple associations between two classes
      :show_sti => true,                         # show STI classes
      :sti_fields => true,                       # show fields of STI classes where declared if using modalfields
      :unified_polymorphic => false,             # unify the circled end of polymorphic associations
      :no_association_labels=>false,             # don't show association labels
      :output_tools => %w{dot fdp neato}         # graphviz styles (tools) used whe generating output (ps/png/pdf)
    ].merge Settings.load(Rails.root.join('config','modal_diagrams.yml'))
  end

end