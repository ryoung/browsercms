class AbstractFileBlock < ActiveRecord::Base
  
  set_table_name "file_blocks"
      
  validates_presence_of :name  
  
  named_scope :by_section, lambda { |section| { :include => {:attachment => :section_node }, :conditions => ["section_nodes.section_id = ?", section.id] } } 
  
  def path
    attachment_file_path
  end
  
  def self.publishable?
    true
  end

  def set_attachment_path
    if @attachment_file_path && @attachment_file_path != attachment.file_path
      attachment.file_path = @attachment_file_path
    end
  end

  def set_attachment_section
    if @attachment_section && @attachment_section != attachment.section
      attachment.section = @attachment_section
    end
  end

end