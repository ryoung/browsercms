class Cms::PagesController < Cms::BaseController
  
  skip_before_filter :login_required, :only => [:show]
  before_filter :load_section, :only => [:new, :create, :move_to]
  before_filter :load_page, :only => [:edit, :revisions, :show_version, :move_to, :revert_to, :destroy]
  before_filter :hide_toolbar, :only => [:new, :create, :move_to]

  verify :method => :put, :only => [:move_to]

  def show
    return redirect_to(Page.find(params[:id]).path) unless params[:id].blank?
    raise ActiveRecord::RecordNotFound.new("Page could not be found") if params[:path].nil?

    #Reconstruct the path from an array into a string
    @path = "/#{params[:path].join("/")}"

    #Try to Redirect
    if redirect = Redirect.find_by_from_path(@path)
      redirect_to redirect.to_path
      return
    end
    
    #Get the extentions
    split = params[:path].last.to_s.split('.')
    ext = split.size > 1 ? split.last.to_s.downcase : nil
    
    #Only try to stream cache file if it has an extension
    unless ext.blank?
      #Construct a path to where this file would be if it were cached
      @file = File.join(ActionController::Base.cache_store.cache_path, @path)

      #Write the file out if it doesn't exist
      unless File.exists?(@file)
        @file_metadata = FileMetadata.find_by_path(@path)
        @file_metadata.write_file if @file_metadata
      end
    
      #Stream the file if it exists
      if @path != "/" && File.exists?(@file)
        send_file(@file, 
          :type => Mime::Type.lookup_by_extension(ext).to_s,
          :disposition => false #see monkey patch in lib/action_controller/streaming.rb
        ) 
        return
      end    
    end
    
    #Last, but not least, to to render a page for this path
    set_page_mode
    @page = Page.find_by_path(@path)
    if @page
      render :layout => @page.layout
    else
      raise ActiveRecord::RecordNotFound.new("No page at '#{@path}'") unless @page    
    end
    
  end

  def new
    @page = @section.pages.build
  end

  def create
    @page = @section.pages.build(params[:page])
    @page.updated_by_user = current_user
    if @page.save
      flash[:notice] = "Page was '#{@page.name}' created."
      redirect_to cms_url(@page)
    else
      render :action => "new"
    end
  end

  def update
    @page = Page.find(params[:id])
    #@page.status = params[:status] || "IN_PROGRESS"
    if @page.update_attributes(params[:page].merge(:updated_by_user => current_user))
      flash[:notice] = "Page was '#{@page.name}' updated."
      redirect_to cms_url(@page)
    else
      render :action => "edit"
    end
  end

  def destroy
    respond_to do |format|
      if @page.destroy
        flash[:notice] = "Page '#{@page.name}' was deleted."
        format.html { redirect_to cms_url(:sitemap) }
        format.js { }
      else
        flash[:error] = "Page '#{@page.name}' could not be deleted"
        format.html { redirect_to cms_url(:sitemap) }
        format.js { render :template => 'cms/shared/show_error' }
      end
    end
    
  end
  
  #status actions
  {:publish => "published", :hide => "hidden", :archive => "archived"}.each do |status, verb|
    define_method status do
      load_page
      if @page.send(status, current_user)
        flash[:notice] = "Page '#{@page.name}' was #{verb}"
      end
      redirect_to @page.path
    end
  end
  
  def show_version
    @page = @page.as_of_version(params[:version])
    render :layout => @page.layout, :action => 'show'
  end  
  
  def move_to
    if @page.move_to(@section, current_user)
      flash[:notice] = "Page '#{@page.name}' was moved to '#{@section.name}'."
    end
    
    respond_to do |format|
      format.html { redirect_to cms_path(@section, :page_id => @page) }
      format.js { render :template => 'cms/shared/show_notice' }
    end    
  end
  
  def revert_to
    if @page.revert_to(params[:version], current_user)
      flash[:notice] = "Page '#{@page.name}' was reverted to version #{params[:version]}"
    end
    
    respond_to do |format|
      format.html { redirect_to @page.path }
      format.js { render :template => 'cms/shared/show_notice' }
    end    
  end
  
  private

    def load_page
      @page = Page.find(params[:id])
    end
  
    def load_section
      @section = Section.find(params[:section_id])
    end
  
    def set_page_mode
      @mode = params[:mode] || session[:page_mode] || "view"
      session[:page_mode] = @mode      
    end
  
    def hide_toolbar
      @hide_page_toolbar = true
    end
  
end
