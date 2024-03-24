#property copyright "vntech"
#property link      "howtrader"
#property version   "1.00"
#property strict

#include <Zmq/Zmq.mqh>
#include <JAson.mqh>

#define FUNCTION_QUERYCONTRACT 0
#define FUNCTION_QUERYORDER 1
#define FUNCTION_QUERYHISTORY 2
#define FUNCTION_SUBSCRIBE 3
#define FUNCTION_SENDORDER 4
#define FUNCTION_CANCELORDER 5

input string HOSTNAME = "*";
input int REP_PORT = 6888;
input int PUB_PORT = 8666;
input int MILLISECOND_TIMER = 10;

Context context("howtrader");
Socket rep_socket(context, ZMQ_REP);
Socket pub_socket(context, ZMQ_PUB);

string subscribed_symbols[100];
int subscribed_count;
int timer_count;

int OnInit()
{  
   for (int i=0; i<100; ++i)
   {
      subscribed_symbols[i] = "";
   }
   
   timer_count = 0;
   
   EventSetMillisecondTimer(MILLISECOND_TIMER);
   context.setBlocky(false);

   rep_socket.bind(StringFormat("tcp://%s:%d", HOSTNAME, REP_PORT));
   pub_socket.bind(StringFormat("tcp://%s:%d", HOSTNAME, PUB_PORT));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   rep_socket.unbind(StringFormat("tcp://%s:%d", HOSTNAME, REP_PORT));
   rep_socket.disconnect(StringFormat("tcp://%s:%d", HOSTNAME, REP_PORT));
   
   pub_socket.unbind(StringFormat("tcp://%s:%d", HOSTNAME, PUB_PORT));
   pub_socket.disconnect(StringFormat("tcp://%s:%d", HOSTNAME, PUB_PORT));
   
   context.destroy(0);

   EventKillTimer();
}

void OnTick()
{

}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   CJAVal rep_json(NULL, jtUNDEF);
      
   rep_json["type"] = "order";
   
   rep_json["data"]["symbol"] = trans.symbol;
   rep_json["data"]["deal"] = (int) trans.deal;
   rep_json["data"]["order"] = (int) trans.order;
   rep_json["data"]["trans_type"] = (int) trans.type;

   OrderSelect(trans.order);
   rep_json["data"]["order_type"] = (int) OrderGetInteger(ORDER_TYPE);
   rep_json["data"]["order_state"] = (int) OrderGetInteger(ORDER_STATE);
   rep_json["data"]["order_price"] = (double) OrderGetDouble(ORDER_PRICE_OPEN);
   rep_json["data"]["order_volume_initial"] = (double) OrderGetDouble(ORDER_VOLUME_INITIAL);
   rep_json["data"]["order_volume_current"] = (double) OrderGetDouble(ORDER_VOLUME_CURRENT);
   rep_json["data"]["order_comment"] = (string) OrderGetString(ORDER_COMMENT);
   rep_json["data"]["order_time_setup"] = (int) OrderGetInteger(ORDER_TIME_SETUP);
   
   rep_json["data"]["deal_type"] = (int) trans.deal_type;
   rep_json["data"]["trans_price"] = (double) trans.price;
   rep_json["data"]["trans_volume"] = (double) trans.volume;
   rep_json["data"]["trans_state"] = (double) trans.order_state;
   
   rep_json["data"]["result_deal"] = (int) result.deal;
   rep_json["data"]["result_order"] = (int) result.order;
   rep_json["data"]["result_volume"] = (double) result.volume;
   rep_json["data"]["result_price"] = (double) result.price;
   rep_json["data"]["result_retcode"] = (int) result.retcode;
   rep_json["data"]["result_comment"] = (string) result.comment;

   rep_json["data"]["request_action"] = (int) request.action;
   rep_json["data"]["request_type"] = (int) request.type;
   rep_json["data"]["request_comment"] = (string) request.comment;
   

   string rep_data = "";
   rep_json.Serialize(rep_data);

   ZmqMsg rep_msg(rep_data);
   pub_socket.send(rep_msg, true);
}

void OnTimer()
{
  //Publish data
   timer_count += MILLISECOND_TIMER;
   
   if (timer_count >= 100)
   {
      timer_count = 0;
      
      string price_data = get_price_info();
      ZmqMsg price_msg(price_data);
      pub_socket.send(price_msg, true);   
   
      string account_data = get_account_info();
      ZmqMsg account_msg(account_data);
      pub_socket.send(account_msg, true);    
      
      string position_data = get_position_info();
      ZmqMsg position_msg(position_data);
      pub_socket.send(position_msg, true); 
      
   }
   
   //Process new request
   ZmqMsg req_msg;
   string req_data;
   CJAVal req_json(NULL, jtUNDEF);
   int req_type;
   
   rep_socket.recv(req_msg, true);
   if (req_msg.size() <= 0) return;
   
   req_data = req_msg.getData();
   req_json.Deserialize(req_data);
   req_type = req_json["type"].ToInt();
   
   string rep_data = "";
   switch(req_type)
   {
      case FUNCTION_QUERYCONTRACT:
         rep_data = get_contract_info();
         break;

      case FUNCTION_QUERYORDER:
         rep_data = get_order_info();
         break;
                  
      case FUNCTION_QUERYHISTORY:
         rep_data = get_history_info(req_json);
         break;
         
      case FUNCTION_SUBSCRIBE:
         rep_data = subscribe(req_json);
         break;
         
      case FUNCTION_SENDORDER:
         rep_data = send_order(req_json);
         break;
      
      case FUNCTION_CANCELORDER:
         rep_data = cancel_order(req_json);
         break;
   }
   
   ZmqMsg rep_msg(rep_data);
   rep_socket.send(rep_msg, true);   
}

string get_contract_info()
{
   CJAVal rep_json(NULL, jtUNDEF);
   string symbol;
   
   int total_symbol = SymbolsTotal(false);
   for (int i=0; i<total_symbol; ++i)
   {
      symbol = SymbolName(i, false);
      rep_json["data"][i]["symbol"] = symbol;
      rep_json["data"][i]["digits"] = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      rep_json["data"][i]["lot_size"] = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      rep_json["data"][i]["min_lot"] = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string get_account_info()
{
   CJAVal rep_json(NULL, jtUNDEF);
   
   rep_json["type"] = "account";
      
   rep_json["data"]["name"] = AccountInfoString(ACCOUNT_NAME);
   rep_json["data"]["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
   rep_json["data"]["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
   rep_json["data"]["free_margin"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   rep_json["data"]["profit"] = AccountInfoDouble(ACCOUNT_PROFIT);
   rep_json["data"]["currency"] = AccountInfoString(ACCOUNT_CURRENCY);
   rep_json["data"]["company"] = AccountInfoString(ACCOUNT_COMPANY);
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string get_price_info()
{
   CJAVal rep_json(NULL, jtUNDEF);
   string symbol;
   
   rep_json["type"] = "price";
   
   for (int i=0; i<100; ++i)
   {
      symbol = subscribed_symbols[i];
      
      if (symbol == "")
      {
         break;
      }
      
      rep_json["data"][i]["symbol"] = symbol;
      rep_json["data"][i]["bid_high"] = SymbolInfoDouble(symbol, SYMBOL_BIDHIGH);
      rep_json["data"][i]["ask_high"] = SymbolInfoDouble(symbol, SYMBOL_ASKHIGH);
      rep_json["data"][i]["last_high"] = SymbolInfoDouble(symbol, SYMBOL_LASTHIGH);
      rep_json["data"][i]["ask_low"] = SymbolInfoDouble(symbol, SYMBOL_ASKLOW);
      rep_json["data"][i]["bid_low"] = SymbolInfoDouble(symbol, SYMBOL_BIDLOW);
      rep_json["data"][i]["last_low"] = SymbolInfoDouble(symbol, SYMBOL_LASTLOW);     
      rep_json["data"][i]["time"] = SymbolInfoInteger(symbol, SYMBOL_TIME);
      rep_json["data"][i]["last"] = SymbolInfoDouble(symbol, SYMBOL_LAST);
      rep_json["data"][i]["bid"] = SymbolInfoDouble(symbol, SYMBOL_BID);
      rep_json["data"][i]["ask"] = SymbolInfoDouble(symbol, SYMBOL_ASK); 
      rep_json["data"][i]["last_volume"] = SymbolInfoDouble(symbol, SYMBOL_VOLUME_REAL);
   }
  
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string send_order(CJAVal &req_json)
{
   CJAVal rep_json(NULL, jtUNDEF);
  
   MqlTradeRequest request = {}; 
   MqlTradeResult result = {}; 
   //--- 归零请求和结果值
   ZeroMemory(request);
   ZeroMemory(result);

   int cmd = req_json["cmd"].ToInt();
   int magic_id = req_json["magic"].ToInt();
   string offset = req_json["offset"].ToStr();
   
   request.action = (((cmd == ORDER_TYPE_BUY) || (cmd == ORDER_TYPE_SELL)) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING);    // 交易操作类型
   request.symbol = req_json["symbol"].ToStr();  // 交易品种 
   request.volume = req_json["volume"].ToDbl();      // 交易量
   request.sl = 0;                                
   request.tp = 0;    
   request.deviation=5;                        // 允许价格偏差
   request.comment = req_json["comment"].ToStr(); //本地id
   request.magic    =magic_id;             // 持仓幻数
   if(offset =="open")
      {
         request.price = req_json["price"].ToDbl();                                                         
         request.type = (ENUM_ORDER_TYPE)cmd;   
         //--- 输出开仓信息
         Print("下单开仓-交易品种-订单类型-下单价格-下单数量",request.symbol,"___",request.type,"___",request.price,"___",request.volume);         
         
      }
   if(offset =="close" )
    {
         int total=PositionsTotal(); // 持仓数   
         for(int i=total-1; i>=0; i--)
            {
                  //--- 订单的参数
               ulong  position_ticket=PositionGetTicket(i);                                      // 持仓价格
               string position_symbol=PositionGetString(POSITION_SYMBOL);                        // 交易品种 
               int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // 小数位数
               ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // 持仓的幻数
               ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // 持仓类型
                     //--- 输出持仓信息
               Print("持仓id ：",position_ticket);
               Print("交易品种  ：",position_symbol);
               Print("持仓类型 ：",EnumToString(type));
               Print("开仓价格 ：",DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits));
               Print("持仓的幻数 ：",magic);
               if(magic==magic_id)
                  {
                     //--- 设置操作参数
                     request.position =position_ticket;          // 持仓价格
                              //--- 根据持仓类型设置价格和订单类型 
                              //市价卖出平仓
                     if(type==POSITION_TYPE_BUY && cmd == ORDER_TYPE_SELL)
                       {
                        request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
                        request.type =ORDER_TYPE_SELL;
                        Print("市价平多  ",request.price);
                       }
                       //市价买入平仓
                     if(type==POSITION_TYPE_SELL && cmd == ORDER_TYPE_BUY)
                       {
                        request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
                        request.type =ORDER_TYPE_BUY;
                        Print("市价平空  ",request.price);
                       }
                       
                             //限价卖出平仓
                     if(type==POSITION_TYPE_BUY && cmd == ORDER_TYPE_SELL_LIMIT)
                       {
                        request.price = req_json["price"].ToDbl();
                        request.type =ORDER_TYPE_SELL_LIMIT;
                        Print("限价平多  ",request.price);
                       }
                       //限价买入平仓
                     if(type==POSITION_TYPE_SELL && cmd == ORDER_TYPE_BUY_LIMIT)
                       {
                        request.price = req_json["price"].ToDbl();
                        request.type =ORDER_TYPE_BUY_LIMIT;
                        Print("限价平空  ",request.price);
                       }
                                                    //stop卖出平仓
                     if(type==POSITION_TYPE_BUY && cmd == ORDER_TYPE_SELL_STOP)
                       {
                        request.price = req_json["price"].ToDbl();
                        request.type =ORDER_TYPE_SELL_STOP;
                        Print("stop平多  ",request.price);
                       }
                       //stop买入平仓
                     if(type==POSITION_TYPE_SELL && cmd == ORDER_TYPE_BUY_STOP_LIMIT)
                       {
                        request.price = req_json["price"].ToDbl();
                        request.type =ORDER_TYPE_BUY_STOP_LIMIT;
                        Print("stop平空  ",request.price);
                       }
                       
                       
                       
                              //--- 输出关闭信息
                     PrintFormat("下单平仓-持仓id-交易品种-持仓类型 #%I64d %s %s",position_ticket,position_symbol,EnumToString(type));

                                 
                  
                  }
                    
                           
            
            }
    }
   
   bool n = OrderSendAsync(request, result); 
   rep_json["type"] = "send";
   rep_json["data"]["result"] = n;
   rep_json["data"]["retcode"] = (int) result.retcode;
   rep_json["data"]["comment"] = (string) result.comment;
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string cancel_order(CJAVal &req_json)
{
   CJAVal rep_json(NULL, jtUNDEF);
   string symbol;
   
   int ticket = req_json["ticket"].ToInt();
   
   MqlTradeRequest request = {};
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   
   MqlTradeResult result = {}; 

   bool n = OrderSendAsync(request, result);
   
   rep_json["type"] = "cancel";
   rep_json["data"]["result"] = n;
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}
 
string subscribe(CJAVal &req_json)
{
   CJAVal rep_json(NULL, jtUNDEF);
    
   string symbol = req_json["symbol"].ToStr();
   bool new_symbol = true;

   for (int i=0; i<100; ++i)
   {
      if (subscribed_symbols[i] == "")
      {
         break;
      }
      
      if (subscribed_symbols[i] == symbol) 
      {
         new_symbol = false;
         break;
      }
   }
   
   if (new_symbol == true && SymbolInfoInteger(symbol, SYMBOL_EXIST))
   {
      SymbolSelect(symbol, true);

      subscribed_symbols[subscribed_count] = symbol;
      subscribed_count += 1;
   }
    
   rep_json["type"] = "subscribe";
   rep_json["data"]["new_symbol"] = new_symbol;
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

  
string get_history_info(CJAVal &req_json)
{
   CJAVal rep_json(NULL, jtUNDEF);

   rep_json["type"] = "history";  
    
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   
   int copied = CopyRates(
      req_json["symbol"].ToStr(),
      (ENUM_TIMEFRAMES) req_json["interval"].ToInt(),
      StringToTime(req_json["start_time"].ToStr()),
      StringToTime(req_json["end_time"].ToStr()),
      rates
   );
   
   if (copied > 0)
   {
      int size = fmin(copied, ArraySize(rates));
      for(int i=0; i<size; i++)
        {
         rep_json["result"] = 1;
         rep_json["data"][i]["time"] = TimeToString(rates[i].time);
         rep_json["data"][i]["open"] = rates[i].open;
         rep_json["data"][i]["high"] = rates[i].high;
         rep_json["data"][i]["low"] = rates[i].low;
         rep_json["data"][i]["close"] = rates[i].close;
         rep_json["data"][i]["real_volume"] = rates[i].real_volume;
        }
   }
   else
   {
      rep_json["result"] = -1;
   } 
        
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string get_position_info()
{
   CJAVal rep_json(NULL, jtUNDEF);

   rep_json["type"] = "position";
   
   int position_count = PositionsTotal();
   for(int i=0; i<position_count; i++)
   {
      string symbol = PositionGetSymbol(i); 
      if (symbol != 0) 
      {
         rep_json["data"][i]["price"] = PositionGetDouble(POSITION_PRICE_OPEN);
         rep_json["data"][i]["type"] = (int) PositionGetInteger(POSITION_TYPE);
         rep_json["data"][i]["symbol"] = PositionGetString(POSITION_SYMBOL); 
         rep_json["data"][i]["volume"] = PositionGetDouble(POSITION_VOLUME); 
         rep_json["data"][i]["current_profit"] = PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}

string get_order_info()
{
   CJAVal rep_json(NULL, jtUNDEF);
   
   rep_json["type"] = "order";
   
   int order_count = OrdersTotal();
   for(int i=0;i<order_count;i++)
   {
      string ticket = OrderGetTicket(i);
      OrderSelect(ticket);
      
      rep_json["data"][i]["symbol"] = OrderGetString(ORDER_SYMBOL);
      rep_json["data"][i]["order"] = ticket;
      rep_json["data"][i]["order_type"] = OrderGetInteger(ORDER_TYPE);
      rep_json["data"][i]["order_state"] = OrderGetInteger(ORDER_STATE);
      rep_json["data"][i]["order_price"] = OrderGetDouble(ORDER_PRICE_OPEN);
      rep_json["data"][i]["order_volume_initial"] = OrderGetDouble(ORDER_VOLUME_INITIAL);
      rep_json["data"][i]["order_volume_current"] = OrderGetDouble(ORDER_VOLUME_CURRENT);
      rep_json["data"][i]["order_comment"] = OrderGetString(ORDER_COMMENT);
      rep_json["data"][i]["order_time_setup"] = (int) OrderGetInteger(ORDER_TIME_SETUP);
   }
 
   string rep_data = "";
   rep_json.Serialize(rep_data); 
   return rep_data;
}