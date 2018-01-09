class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, :only => [:active_request_new]
  def new
    if current_user.nil?
      @user = User.new
    else
      @user = current_user
    end
  end

  def create
    @user = User.new(users_params)
    isNew = true
    if users_params['id'] != nil 
      @user.id = users_params['id']
      isNew = false
    end
    @user.role = "inactive"
    if @user.save
      if isNew != false
        flash[:success] = "Cadastrado com Sucesso!"
        cpt_transaction_user(@user)
        redirect_to '/dashboard/index'
      else
        flash[:success] = "Sucesso!"
        redirect_to '/dashboard/index'
      end
    else
      render :new
    end
  end
  def edit
    @user = current_user
  end
  
  def active_request_new
    request = current_user.active_request.new
    request.document_photo = params[:photo]
    request.document_selfie = params[:selfie]
    request.status = 'pendente'
    request.save
    flash[:success] = 'Seu pedido de ativação foi enviado! Você receberá uma mensagem em seu email com a qualquer atualização em breve.'
    redirect_to '/dashboard/index'
  end

  private

  def users_params
    params.require(:user).permit(:email, :password, :password_confirmation, :username, :birth, :document, :phone, :first_name, :last_name)
  end
end