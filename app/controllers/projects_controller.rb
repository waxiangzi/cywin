class ProjectsController < ApplicationController
  before_action :authenticate_user!, except: [ :index ]

  def index
    @projects = Project.published
  end

  def new
    @project = Project.new
    @project.build_contact
  end

  def edit
    @project = Project.find(params[:id])
  end

  # 创建第一步
  def create
    @project = Project.new(project_params)
    @project.add_owner( current_user )
    if @project.save
      redirect_to stage1_project_path(@project.id)
    else
      render :new
    end
  end

  # 创建第二步
  def stage1
    @project = Project.find(params[:id])
    @owner = @project.owner
    @member = @project.member(@owner)
    if request.post?
      avatar_params = params.require(:project).require(:owner).permit(:avatar, :avatar_cache)
      if avatar_params
        unless @owner.update(avatar_params)
          render :stage1
          return
        end
      end
      member_params = params.require(:project).require(:member).permit(:title, :description)
      unless @member.update(member_params)
        render :stage1
        return
      end
      redirect_to stage2_project_path(params[:id])
      return
    # get
    else
      render :stage1
      return
    end
  end

  # 创建第三步
  def stage2
    @project = Project.find(params[:id])
    if request.post?
      # add money_require
      money_require_flag = params.permit(:money_require)[:money_require]
      if money_require_flag
        money_require_params = params.require(:project).require(:money_requires).permit(:money, :share, :deadline, :description)
        @money_require = MoneyRequire.new(money_require_params)
        @project.money_requires << @money_require
      end
      #TODO 多人招聘的支持
      person_require_flag = params.permit(:person_require)[:person_require]
      if person_require_flag
        person_requires_params = params.require(:project).require(:person_requires).permit(:title, :pay, :stock, :option, :description)
        @person_require = PersonRequire.new(person_requires_params)
        @project.person_requires << @person_require
      end
      if @project.save
        flash[:notice] = "项目创建成功"
        redirect_to edit_project_path(@project.id)
        return
      else
        render :stage2
        return
      end
    # get
    else
      @money_require = @project.money_requires.build
      @person_require = PersonRequire.new
      render :stage2
      return
    end
  end

  def publish
    @project = Project.find(params[:id])
    if @project.publish
      flash[:notice] = "发布成功"
      render_success("发布项目成功")
    else
      render_fail("发布失败")
    end
  end

  # 发起一个新的融资
  def invest
    @project = Project.find(params[:id])
    money_require_params = params.require(:money_require).permit(:money, :share, :description, :deadline)
    @money_require = MoneyRequire.new(money_require_params)
    @project.money_requires << @money_require
    if @project.save
      @money_require.start!
      flash[:notice] = "发起融资成功"
      render template: 'syndicates/syndicate_info', layout: false
    else
      render_fail(@money_require.errors.full_messages.to_s)
    end
  end

  # 关闭一个打开中的融资
  def close_investment
    @money_require = MoneyRequire.find(params[:id])
    @project = @money_require.project
    begin
      @money_require.close!
      flash[:notice] = "关闭融资成功"
      render template: 'syndicates/syndicate_info', layout: false
    rescue =>e
      render_fail(e.message)
    end
  end

  # 发起一个新的招聘
  def invite
    @project = Project.find(params[:id])
    person_requires_params = params.require(:person_require).permit(:title, :pay, :stock, :option, :description)
    @person_require = PersonRequire.new(person_requires_params)
    @project.person_requires << @person_require
    if @project.save
      render_success
    else
      render_fail(@project.errors)
    end
  end

  def update
  end

  def show
    @project = Project.find(params[:id])
  end

  private
  def project_params
    new_params = params
    new_params = params.require(:project) if params[:project]
    new_params.permit(:id, :logo, :logo_cache, :name, :oneword, :description, :stage, :where1, :where2, :where3, contact_attributes: [ :address, :phone, :qq, :weixin, :weibo ])
  end

end
