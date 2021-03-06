class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper_method :current_user_session, :current_user, :get_saldo, :require_user, :deliver_deposit_email, :blocker_link, :optax, :last_price, :deliver_generic_email, :check_cur_nil, :broadcast_order, :recent_orders, :exchange_label, :search_saldo, :check_user_documents, :price_percentage, :color_type_percentage, :encrypt_data, :decrypt_data, :exchange_tax
  require 'sendgrid-ruby'
  include SendGrid 
  private
  def exchange_tax(input)
    return (BigDecimal((BigDecimal(input,8) * BigDecimal(ENV["EXCHANGE_TAX"],4)),8)).to_s
  end
  def price_percentage(pair)
    last_order = Exchangeorder.where("par = :str_pair AND status = :stt", {str_pair: pair, stt: "executada" }).order("updated_at DESC").first
    last_order_24h = Exchangeorder.where("par = :str_pair AND status = :stt AND updated_at > :date", {str_pair: pair, stt: "executada" , date: Time.now - 1.days}).first
    if !(last_order.nil?) && !(last_order_24h.nil?) #calculável
      a = BigDecimal(last_order.price,8)
      b = BigDecimal(last_order_24h.price,8)
      c = ((a-b)/b) * 100
      return "#{c.to_s.split(".")[0].first(3)},#{c.to_s.split(".")[1].first(2)}"
    end
    return "0"
  end
  def color_type_percentage(decimal)
    decimal_o = BigDecimal(decimal,8)
    case 
    when decimal_o == 0
      "yellow"
    when decimal_o < 0
      "red"
    when decimal_o > 0
      "green"
    end
  end
  def check_user_documents
    case current_user.role
    when "inactive"
      return true
    when "active"
    else
      return false
    end
  end
  
  def decrypt_data(message)
    decipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    decipher.decrypt
    decipher.key = ENV["CIPHER_RANDOM"]
    decipher.iv = ENV["CIPHER_IV"]
    tempkey = Base64.decode64(message)
    crypt = decipher.update(tempkey)
    crypt << decipher.final()
    return crypt
  end
  
  def encrypt_data(message)
    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.encrypt # We are encypting
    # The OpenSSL library will generate random keys and IVs
    cipher.key = ENV["CIPHER_RANDOM"]
    cipher.iv = ENV["CIPHER_IV"]
    
    encrypted_data = cipher.update(message) # Encrypt the data.
    encrypted_data << cipher.final
    crypt_string = (Base64.encode64(encrypted_data))
    return crypt_string
  end
  
  def search_saldo
    eval(get_saldo(current_user))
  end
  def exchange_label(text)
    case text.downcase
    when "deposit_operation_verified"
      return "Depósito verificado"
    when "deposit_cancelled"
      return "Depósito Cancelado"
    when "deposit_operation"
      return "Aguardando documento"
    when "deposit_operation_pendent"
      return "Depósito em análise"
    when "deposit_operation_complete"
      return "Depósito completo"
    when 'deposit'
      return "Depósito"
    when 'open_order_sell'
      return "Abertura de ordem"
    when 'open_order_buy'
      return "Abertura de ordem"
    when 'buy_order_execution'
      return "Execução de ordem"
    when 'sell_order_execution'
      return "Execução de ordem"
    when 'open_order'
      return "Ordem aberta"
    when 'cancel_buy'
      return "Cancelamento de ordem"
    when 'exchange_open_order_buy'
      return "Ordem de compra"
    when 'exchange_open_order_sell'
      return "Ordem de venda"
    when 'exchange_cancel_buy'
      return "Ordem de compra"
    when 'exchange_cancel_sell'
      return "Cancelamento de ordem"
    when 'cancel_sell'
      return "Cancelamento de ordem"
    when 'exchange_buy_order_execution'
      return "Ordem de compra"
    when 'exchange_sell_order_execution'
      return "Ordem de Venda"
    when 'incomplete'
      return "Incompleto"
    else
      return text
    end
      
  end
  
  def require_admin
    require_user
    current_user.role.to_s
    unless current_user.role.to_s == "admin" 
      flash[:info] = "Esta página requer permissões administrativas!"
      redirect_to '/'
    end
  end
  def check_cur_nil
    if session[:currency1].nil?
      base_par = EXCHANGE_PARES.first.tr(" ","").split("/")
      session[:currency1] = base_par[0]
      session[:currency2] = base_par[1]
    end
  end
  def broadcast_order(order)
        ActionCable.server.broadcast 'last_orders',
            status: order.status
  end
  def last_price(pares,tipo,execucao)
    if tipo.nil? && execucao.nil?
      a = Exchangeorder.where("par = :par and status = :stt", { stt: "executada", par: pares}).order("updated_at DESC").first
    else
      a = Exchangeorder.where("par = :par and tipo = :role and status = :stt", { stt: execucao, par: pares, role: tipo }).order("updated_at DESC").first
    end
    if !a.nil?
      a.price
    else
      "NaN"
    end
  end
  
  def blocker_link(network)
    ENV["LINK#{network}"]
  end
  
  def optax(currency)
        TAXES[currency.upcase].to_f
  end
  
  
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end
  
  def require_user
    unless !current_user.nil? 
      flash[:info] = "Esta página requer login!"
      redirect_to '/sign_in'
    end
  end
  
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def cpt_push(route,params)
    url = URI.parse("#{ENV["TRANSACTION_URL"]}#{route}")
    req = Net::HTTP::Post.new(url.request_uri)
    params['key'] = ENV['TRANSACTION_KEY']
    
    cipher = OpenSSL::Cipher.new('AES-128-CBC')
    cipher.encrypt
    cipher.key = ENV["CIPHER_RANDOM"]
    cipher.iv = ENV["CIPHER_IV"]
    message = cipher.update(params.to_s) + cipher.final
    
    params = Hash.new
    params[:message] = message
    req.set_form_data(params)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == "https")
    response = http.request(req)
    response.body
  end
  #operações de saldo
  def cpt_transaction_user(user) #criar usuário
    route = 'add_users'
    params = {'username'=> user.username, 'email'=> user.email, 'id_original'=> user.id, 'name'=> "#{user.first_name} #{user.last_name}"}
    cpt_push(route,params)
  end
  
  def cpt_update_user(user)
    route = 'update_users'
    params = {'username'=> user.username, 'email'=> user.email, 'id_original'=> user.id, 'name'=> "#{user.first_name} #{user.last_name}"}
    cpt_push(route,params)
  end
  
  def add_saldo(usuario,moeda,qtd,tipo) #função para adicionar saldo
    route = 'add_saldo'
    params = {'email' => usuario.email, 'id_original' => usuario.id, 'currency' => moeda, 'amount' => (BigDecimal(qtd,8)).to_s, 'type' => tipo}
    tries = 0
    hash = eval(cpt_push(route,params))
    while tries < 10 #caso a operação falhe, tentar novamente
      if hash["status"] != "ok"
        sleep 3
        hash = eval(cpt_push(route,params))
        tries += 1
      else
        return hash["id"]
      end #if
    end #while
  end #def
  
  def get_saldo(usuario)
    route = 'get_saldo'
    params = {'id_original'=> usuario.id}
    a = cpt_push(route,params)
    a
  end
  
  def cpt_transaction_add(currency,type,user_id,debit_credit,amount)
    route 'add_transaction'
    params = {'currency'=> currency, 'type'=> type, 'user_id'=> user_id, 'debit_credit'=> debit_credit, 'amount'=> amount}
    cpt_push(route,params)
  end
  
  def deliver_generic_email(user,text,title)
    string_body = text
    from = Email.new(email: 'no-reply@cptcambio.com')
    subject = "#{title} - CPT Cambio"
    to = Email.new(email: user.email)
    content = Content.new(type: 'text/html', value: string_body)
    mail = Mail.new(from, subject, to, content)

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._("send").post(request_body: mail.to_json)
    puts response.status_code
  end
  
  def deliver_deposit_email(user,currency,amount,discounted)
    string_body = ""
    string_body << "Olá "
    string_body << "#{user.first_name.capitalize} #{user.last_name.capitalize} "
    string_body << "<br>"
    string_body << "Obrigado por utilizar nossos serviços!<br> Foi realizado um depósito líquido de #{discounted} #{currency} em sua conta.<br>"
    string_body << "\n"
    string_body << "Caso queira verificar detalhes do depósito, acesse nosso sistema.<br>Bons negócios!"
    
    from = Email.new(email: 'no-reply@cptcambio.com')
    subject = 'Depósito - CPT Cambio'
    to = Email.new(email: user.email)
    content = Content.new(type: 'text/html', value: string_body)
    mail = Mail.new(from, subject, to, content)

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    sg.client.mail._("send").post(request_body: mail.to_json)
  end
end
