class QuestionsController < ApplicationController
  layout false ,:only => :show
  before_filter :chk_user


    def chk_user
    if !current_user.has_role?('Add Questions Only','Manage Questions','Add Questions')
      redirect_to '/homes/index'
    end
    end

      def index
        @questions= Question.filtered(params[:search],params[:srch]).paginate(:page => params[:page], :per_page => 15)
 #       @questions=Question.paginate(:page => params[:page], :per_page => 10)
        if my_roles.include?('Add Questions')&&!my_roles.include?('Manage Questions')
          @questions.select! {|q| q.created_by==current_user.user_email}

        elsif (my_roles.include?('Add Questions Only')&&!my_roles.include?('Manage Questions')&&!my_roles.include?('Add Questions'))
           @questions.select! {|q| q.created_at>=(Time.now-1.minutes)&&q.created_by==current_user.user_email }

        end
        @complexity=Complexity.first(3)
        @category=Category.all
        @types=Type.all
        @users=Question.select("created_by").uniq
        @ids=Array.new(@questions.count)
        respond_to do |format|
          format.html
          format.json { render json: @questions }
        end

      end

      def show
        @question = Question.find(params[:id])
        @options = @question.options.all
        respond_to do |format|
          format.html
          format.json { render json: @question }
        end
      end


      def new
        @question = Question.new
        @complexity=Complexity.first(3)
        @categorys=Category.all
        @types=Type.all
        respond_to do |format|
          format.html
          format.json { render json: @question }
        end
      end


      def edit
        @question = Question.find(params[:id])
        @opt=@question.options.all
        @complexity=Complexity.first(3)
        @categorys=Category.all
        @types=Type.all

      end


      def create
        @question = Question.new(params[:question])
        @question.created_by =current_user.user_email
        @question.answer_id=""
        @question.type_id=""
        @complexity=Complexity.first(3)
        @categorys=Category.all
        @types=Type.all
          if @question.save
              redirect_to questions_path , notice: 'Question was successfully created.'
          else
    #        4.times { @question.options.build }
              render action: "new"
          end
      end


      def update
        @question = Question.find(params[:id])
        params[:question][:updated_by]=current_user.user_email
        @complexity=Complexity.first(3)
        @categorys=Category.all
        @types=Type.all
        @opt=@question.options.all
        flag=0
        params[:question]['options_attributes'].each {|k,v| flag=1 if v['is_right']=='1'}
        if params[:question][:question]==""&&params[:question][:question_image].nil?
            flash.now[:error]="Question or image should not be blank"
            render action: "edit"
            return
        end
        if flag==0

            flash.now[:error]="atleast one option should be true"
            render action: "new"
            return
        end
        respond_to do |format|
          if @question.update_attributes(params[:question])
            @question.options.first.save
            format.html { redirect_to questions_path , notice: 'Question was successfully updated.' }
            format.json { head :no_content }
          else
            @complexity=Complexity.all
            @category=Category.all
            @types=Type.all
            @opt=@question.options.all
            format.html { render action: "edit" }
            format.json { render json: @question.errors, status: :unprocessable_entity }
          end
        end
      end


      def destroy
        @question = Question.find(params[:id])
        @question.destroy

         redirect_to questions_url, notice: 'Question was successfully deleted.'

      end

  def delete_all
    flag=0
    nothing_to_delete=1
    if !params[:to_delete].nil?
     params[:to_delete].each do |k,v|
        @question=Question.find(k.to_i)
        flag=1 if !@question.exams.empty?&&v.to_i==1
        if v.to_i==1&&@question.exams.empty?
          @question.delete
          nothing_to_delete=0
        end

     end
     if flag==1
       flash[:warning]="some questions are part of question paper.So you cant delete."
     elsif nothing_to_delete==1
       flash[:error]="Nothing to delete"
     else
       flash[:notice]="Question's' deleted successfully"
     end

    end
    redirect_to questions_path
  end

  def delete_image
    @question=Question.find(params[:id])
    @question.question_image.clear
    @question.save(validate: false)
    redirect_to edit_question_path(@question)
  end
end
