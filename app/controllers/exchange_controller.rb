class ExchangeController < ApplicationController
    def render_orders
        session[:currency1] = params[:coin1]
        session[:currency2] = params[:coin2]
    end
    
    def cancel_order
        @order = current_user.exchangeorder.find(params[:id])
        par = @order.par.split('/')
        if (@order.status != "open") and (@order.status != "executada")
            return
        end
        @order.status = "cancelled"
        flash[:success] = "Ordem cancelada! "
        
        case @order.tipo
        when "buy"
            p add_saldo(current_user,par[1],(BigDecimal(@order.amount,8) * BigDecimal(@order.price,8)).to_s,"cancel_buy")
        when "sell"
            p add_saldo(current_user,par[0],@order.amount,"cancel_sell")
        end
        if @order.save
            broadcast_order(@order)
        end
    end
    
    def open_orders
        if session[:current_place] == "overview"
            render :json => json_last_price
        end
    end
    
    def create_order
        saldos = eval(get_saldo(current_user))
        order = parseOrder(params)
        order.has_execution = false
        total_value = BigDecimal(order.amount,8) * BigDecimal(order.price,8)
        case params[:type]
        when "buy"
            compare_value = total_value
            saldo = saldos[params[:coin2]]
            discount_currency = params[:coin2]
            operation = "exchange_buy"
            consulta_ordem_oposta = Exchangeorder.where("par = :str_par AND tipo = :tupe AND status = :stt AND price <= :preco", {str_par: order.par, tupe: "sell", stt: "open", preco: order.price}).order(price: :asc)
        when "sell"
            compare_value = order.amount
            saldo = saldos[params[:coin1]]
            discount_currency = params[:coin1]
            operation = "exchange_sell"
            consulta_ordem_oposta = Exchangeorder.where("par = :str_par AND tipo = :tupe AND status = :stt AND price >= :preco", {str_par: order.par, tupe: "buy", stt: "open", preco: order.price}).order(price: :desc)
        end
        if saldo >= BigDecimal(compare_value,8)
            
            add_saldo(current_user,discount_currency,compare_value.to_s,operation)
            check_active_orders(order,consulta_ordem_oposta,params[:type])
            flash[:success] = "Ordem adicionada ao livro! "
        else
            flash[:success] = "Não há saldo para iniciar esta negociação "
        end
        @order = order
    end
    
    private
    
    def json_last_price
        result = Hash.new
        EXCHANGE_PARES.each do |k|
            par = k.tr(" ", "")
            result["#{par}_buy"] = last_price(par,"buy","executada")
            result["#{par}_sell"] = last_price(par,"sell","executada")
        end
        result
    end
    def broadcast_order(order)
        if order.status == "executada"
            ActionCable.server.broadcast 'last_orders',
                status: order.status,
                last_price: json_last_price 
        else
            ActionCable.server.broadcast 'last_orders',
                status: order.status
        end
    end
    def check_active_orders(order,consulta_ordem_oposta,buysell)
        inicial_amount = BigDecimal(order.amount,8)
        current_amount = inicial_amount
        if consulta_ordem_oposta.empty?
            if order.save
                broadcast_order(order)
            end
            return 
        end
        consulta_ordem_oposta.each do |b|
            b_amount = BigDecimal(b.amount,8)
            o_amount = BigDecimal(order.amount,8)
            if BigDecimal(current_amount,8) > 0
                case order.tipo
                when "buy", "sell"
                    case 
                    when b_amount > o_amount
                        result_amount = b_amount - o_amount
                        saldo_sell = o_amount #saldo a adicionar pro comprador caso ordem parcelada
                        saldo_buy = o_amount
                        b.amount = result_amount.to_s #resultante do montante das duas ordens é o que sobra na transação do livro convertido em string
                        b.has_execution = true
                        b.save
                        
                        new = Exchangeorder.new
                        new.par = order.par
                        new.user_id = b.user_id
                        new.status = "executada"
                        new.price = b.price
                        new.amount = order.amount
                        new.tipo = order_type(order.tipo)
                        new.has_execution = true
                        if new.save
                            broadcast_order(new)
                        end
                        
                        
                        current_amount = 0
                        order.status = "executora"
                        order.has_execution = true
                        order.save
                    when o_amount >= b_amount
                        result_amount = o_amount - b_amount
                        saldo_sell = b_amount #saldo a adicionar pro comprador caso ordem parcelada de venda
                        saldo_buy = b_amount
                        
                        if result_amount > 0
                            order.has_execution = true
                            order.amount = result_amount
                        else
                            order.status = "executora"  
                        end
                        
                        b.status = "executada"
                        if b.save
                            broadcast_order(b)
                        end
                        current_amount = result_amount
                        order.save
                    end    
                end
                case order.tipo
                when "buy"
                    #adicionar saldo order.amount ao dono da order (compra)
                    p saldo1 = (BigDecimal(saldo_buy,8)*0.995).to_s
                    p "adicionar saldo de #{saldo1} #{params[:coin1]} para #{User.find(order.user_id).first_name}"
                    p add_saldo(User.find(order.user_id),params[:coin1],saldo1,"exchange_credit")
                    #adicionar saldo b.amount * b.price ao dono da b (compra)
                    p saldo2 = (BigDecimal(((saldo_buy * BigDecimal(b.price,8))*0.995),8)).to_s
                    p "adicionar saldo de #{saldo2} #{params[:coin2]} para #{User.find(b.user_id).first_name}"
                    p add_saldo(User.find(b.user_id),params[:coin2],saldo2,"exchange_credit")
                when "sell"
                    
                    p coin2_sell_price = ((BigDecimal(saldo_sell,8) * BigDecimal(b.price,8)) * 0.995).to_s
                    p "adicionar saldo de #{BigDecimal(coin2_sell_price,8)} #{params[:coin2]} para #{User.find(order.user_id).first_name}"
                    p add_saldo(User.find(order.user_id),params[:coin2],BigDecimal(coin2_sell_price,8),"exchange_credit")
                    
                    
                    p coin1_sell_price = BigDecimal((saldo_sell * 0.995),8).to_s
                    p "adicionar saldo de #{coin1_sell_price} #{params[:coin1]} para #{User.find(b.user_id).first_name}"
                    p add_saldo(User.find(b.user_id),params[:coin1],coin1_sell_price,"exchange_credit")
                end
            end
        end
        #head :ok
    end
    def order_type(arg)
        if arg == "buy"
            'sell'
        else
            'buy'
        end
    end
    def parseOrder(params)
        new_order = current_user.exchangeorder.new
        new_order.par = "#{params[:coin1]}/#{params[:coin2]}"
        new_order.tipo = params[:type]
        new_order.amount = params[:amount]
        new_order.price = params[:price]
        new_order.status = "open"
        new_order
    end
    def conclude_orders(order1,order2)
    end
end
