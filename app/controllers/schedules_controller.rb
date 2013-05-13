class SchedulesController < ApplicationController
    before_filter :chk_user
   before_filter :new_sch ,:only =>  [:new,:create]
   before_filter :re_sch ,:only =>  [:edit,:update]
   before_filter :cancel_sch ,:only =>  [:remove,:destroy]
    def new_sch
     if !(my_roles.include?('Schedule'))
        redirect_to '/homes/index'
     end

     end

   def re_sch
    if !(my_roles.include?('Re Schedule'))
       redirect_to '/homes/index'
    end

   end

   def cancel_sch
    if !(my_roles.include?('Cancel Schedule'))
       redirect_to '/homes/index'
    end

  end



  def index
    @schedules = Schedule.filtered(params[:search]).paginate(:page => params[:page], :per_page => 20)
    @users=Schedule.select("created_by").uniq
     respond_to do |format|
      format.html 
      format.json { render json: @schedules }
    end

  end


  def show
    @schedule = Schedule.find(params[:id])

    respond_to do |format|

      format.html 
      format.json { render json: @schedule }
    end
  end


  def new
    @exam=Exam.all
    @schedule = Schedule.new
    @candidates=Candidate.all
     @candidates.delete_if {|c| !c.user.isAlive || !c.schedule_id.nil?  }
    respond_to do |format|
      format.html 
      format.json { render json: @schedule }
    end
  end


  def edit
    @exam=Exam.all
    @schedule = Schedule. find(params[:id])
    @schedule.sh_date=@schedule.sh_date.strftime("%b-%d-%Y  %I:%M%p")
    @candidates=Candidate.all
    @candidates.select!  {|c| (@schedule.candidates.include?(c) && c.user.isAlive) ||( c.schedule_id.nil? && c.user.isAlive) }

  end


  def create
    @schedule = Schedule.new(params[:schedule])
    @exam=Exam.all
    @candidates=Candidate.all
    @schedule.created_by=current_user.user_email
    @candidates.delete_if {|c| !c.user.isAlive || !c.schedule_id.nil?  }

    if params[:schedule][:candidate_ids].values.join.to_i==0
      flash[:error]="Please select at least one candidate. "
      redirect_to  new_schedule_path
      return
    end
    respond_to do |format|
      if @schedule.save
        @schedule.candidates.each{|c| UserMailer.delay.schedule_email(c.user)  }
        @schedule.candidates.each{|c| UserMailer.schedule_email(c.user).deliver  }
        @users=User.joins(:roles).where(roles: {role_name: "Get Schedule Email"})
        #@users=User.all.select {|usr| usr.roles.include?(Role.find_by_role_name("Get Schedule Email"))}
        @users.each {|admin| UserMailer.delay.admin_schedule_email(admin,@schedule) }
        @users.each {|admin| UserMailer.admin_schedule_email(admin,@schedule).deliver }
        format.html { redirect_to schedules_path, notice: 'Exam was successfully scheduled.' }
        format.json { render json: @schedule, status: :created, location: @schedule }
      else
        format.html { render "new" }
        format.json { render json: @schedule.errors, status: :unprocessable_entity }
      end
    end
  end


  def update
    @schedule = Schedule.find(params[:id])
    @exam=Exam.all
    @candidates=Candidate.all
    @candidates.select!  {|c| (@schedule.candidates.include?(c) && c.user.isAlive) ||( c.schedule_id.nil? && c.user.isAlive) }
    params[:schedule][:updated_by]=current_user.user_email

    if params[:schedule][:candidate_ids].values.join.to_i==0
      flash.now[:error]="Please select at least one candidate. "
      render action: "edit"
      return
    end

     respond_to do |format|
      if @schedule.update_attributes(params[:schedule])
        @schedule.candidates.each{|c| UserMailer.delay.update_schedule_email(c.user) }
        @schedule.candidates.each{|c| UserMailer.update_schedule_email(c.user).deliver }
        @users=User.joins(:roles).where(roles: {role_name: "Get Schedule Email"})
        #@users=User.all.select {|usr| usr.roles.include?(Role.find_by_role_name("Get Schedule Email"))}
        @users.each {|admin| UserMailer.delay.admin_update_schedule_email(admin,@schedule) }
        @users.each {|admin| UserMailer.admin_update_schedule_email(admin,@schedule).deliver }

        format.html { redirect_to @schedule, notice: 'Exam was successfully rescheduled.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @schedule.errors, status: :unprocessable_entity }
      end
    end
  end


  def destroy
    @schedule = Schedule.find(params[:id])
        @schedule.candidates.each{|c| UserMailer.cancel_schedule_email(c.user,@schedule).deliver }
        #@users=User.all.select {|usr| usr.roles.include?(Role.find_by_role_name("Get Schedule Email"))}
        @users=User.joins(:roles).where(roles: {role_name: "Get Schedule Email"})
        @users.each {|admin| UserMailer.cancel_schedule_email(admin,@schedule).deliver }

    @schedule.destroy

    respond_to do |format|
      format.html { redirect_to schedules_url, notice: 'Schedule was successfully cancelled.' }
      format.json { head :no_content }
    end
  end

  def remove
      @schedule=Schedule.find(params[:id])
      @candidate=Candidate.find(params[:candidate_id])
      @schedule.candidates.delete(@candidate)
      @schedule.destroy if @schedule.candidates.empty?
      redirect_to schedule_path(@schedule) if !@schedule.candidates.empty?
      redirect_to schedules_path if @schedule.candidates.empty?
      UserMailer.cancel_schedule_email(@candidate.user,@schedule)
  end

  def chk_user
    if !current_user.has_role?('Schedule','Re Schedule','Cancel Schedule')
       redirect_to '/homes/index'
    end

  end


end
