def has_versions
  extend  VersionExtensions
  include VersionIncludes
end

module VersionExtensions

  def snapshot( version )
    content_with_right_version = []
    content_present_in_this_version = self.where("version <= '#{version}'").group(:uid)
    content_present_in_this_version.each do |c|
      content_with_right_version << self.where(:uid =>c.uid).where("version <= '#{version}'").order('version DESC').first
    end
    return content_with_right_version
  end

  def commitable
    draft.where("created_at!=updated_at")
  end  
  
end

module VersionIncludes
  def self.included(base)
    base.class_eval do
      
      # has_many :histories, :class_name => self.name, :primary_key => :uid, :foreign_key => :uid, :conditions => {:state => 'history' }
    
      # has_one :draft, :class_name => self.name, :primary_key => :uid, :foreign_key => :uid, :conditions => {:state => 'draft' }
    
      # has_one :publication, :class_name => self.name, :primary_key => :uid, :foreign_key => :uid, :conditions => {:state => 'publication' }
    
      scope :uid, lambda {|uid| where(:uid =>uid) }
      scope :publication, where(:state=>'publication')
      scope :draft, where(:state=>'draft')
      scope :with_version, lambda {|version| self.where("version <= '#{version}'") }
      
      before_create 'before_create_initialization'

    end
  end

  def histories
    self.class.where(:uid=>uid).where(:state=>'history').all
  end
  def draft
    self.class.where(:uid=>uid).where(:state=>'draft').all.first
  end  
  def publication
    self.class.where(:uid=>uid).where(:state=>'publication').all.first
  end


  
  def before_create_initialization
    self.state = 'draft'
    self.version = nil
  end
  
  def draft!
    self.state = 'draft'
    self.version = nil
    self.save
  end

  def publish!(version)
    if draft?
      return nil if publication && publication.version >= version
      publication.historize! if publication
      self.state = 'publication'
      self.version = version
      self.save
      create_draft!
    end
  end

  def revert!
    if draft? && publication
      draft = publication.create_draft!
      self.destroy
    end
  end

  def restore!
    if history?
      draft.destroy if draft
      create_draft!
    end
  end

  
 
  def historize!
    if publication?
      self.state = 'history'
      self.save
    end
  end
  
  def create_draft!
    draft = self.clone
    draft.state = 'draft'
    draft.created_at = Time.now
    draft.updated_at = Time.now
    draft.save
  end

  def draft?
    state.eql?('draft')
  end
  
  def publication?
    state.eql?('publication')
  end

  def history?
    state.eql?('history')
  end  
  
  def commitable?
    draft? && (self.created_at!=self.updated_at)
  end 
end