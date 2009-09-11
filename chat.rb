require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'cgi'

class Room < EM::Channel
  attr_accessor :log
  
  def initialize
    @log = []
    super
  end
  def say(msg)
    @log << msg
    push(msg)
  end
end

$room = Room.new
$welcome_html = DATA.read

class Chatter < EventMachine::Connection
  include EventMachine::HttpServer
  
  def unbind
    $room.unsubscribe(@subscription)
  end
 
  def parse_params
    params = ENV['QUERY_STRING'].split('&').inject({}) {|p, s| k,v=s.split('=');p[k.to_s]=CGI.unescape(v.to_s);p}
    params
  end  

  def process_http_request
    puts "#{object_id}: #{method = ENV["REQUEST_METHOD"]} #{action = ENV["PATH_INFO"]} #{ENV["QUERY_STRING"]}"
    
    
    case action
    when '/'      

      response = EventMachine::DelegatedHttpResponse.new( self )
      response.headers['Content-Type'] = 'text/html'
      response.headers['Content-Length'] = $welcome_html.length.to_s
      response.status  = 200
      response.content = $welcome_html
      response.send_response

    when '/log'
      
      response = EventMachine::DelegatedHttpResponse.new( self )
      response.headers['Content-Type'] = 'text/plain'
      response.status  = 200
      response.content = "[#{$room.log.join(',')}]"
      response.send_response

    when '/poll'
      
      response = EventMachine::DelegatedHttpResponse.new( self )
      
      @subscription = $room.subscribe do |msg| 
        response.headers['Content-Type'] = 'text/plain'
        response.status  = 200
        response.content = "[#{msg}]"
        response.send_response
      end
      
    when '/say'
      params = parse_params
      
      $room.say(%|{"msg": #{params["msg"].inspect}, "nick": #{params["nick"].inspect}}|)
      
      response = EventMachine::DelegatedHttpResponse.new( self )
      response.headers['Content-Type'] = 'text/plain'
      response.status  = 200
      response.send_response          
      
    else
      
      response = EventMachine::DelegatedHttpResponse.new( self )
      response.headers['Content-Type'] = 'text/html'
      response.status  = 404
      response.content = %|<h1>Not Found</h1>"|
      response.send_response                
    end    
  end  
end


EventMachine.epoll

EventMachine::run {
  EventMachine::start_server("0.0.0.0", 8080, Chatter)
  puts "Listening on 8080..."
}


__END__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <title>Chat!</title>
    <style>
    body {
      font-size: 8pt;
      font-family: verdana;
    }
    </style>
  <script src="http://ajax.googleapis.com/ajax/libs/prototype/1.6.1.0/prototype.js">
  </script>
  <script>
  
  var tmpl = new Template('<div><strong class="">#{nick}</strong></a><span class="hidden">&gt; </span><span class="message">#{msg}</span></div>');
  
  function say(params) {
    $('chat').appendChild( new Element('div').update( tmpl.evaluate(params) ));
  }
  
  function onData(e) {
    if (e != '' && e != 'nil') {
      eval('var json = ' + e.responseText);
      for (var i=0; i < json.length; i++) {
        say(json[i]);
      };
    }
    setTimeout(poll, 0);
  }
  
  function poll(log){
    new Ajax.Request('/poll', {method: 'get', onSuccess:onData});
  }     
  
  function log(log){
    new Ajax.Request('/log', {method: 'get', onSuccess:onData});
  }     
  
  function put() {
    var msg = $F('msg');
    var nick = $F('nick')
    new Ajax.Request('/say?msg=' + encodeURIComponent(msg) + '&nick=' + encodeURIComponent(nick));
    $('msg').value = '';
  }
  
  $(document).observe('dom:loaded', log);
    
  </script>
  </head>
  <body>
    <div id="chat" style="margin-bottom:4em">
    </div>
    <hr/>
    <form action="/say" method="get" onsubmit="put(); return false;">
    <input type="text" name="nick" value="bob" id="nick" size="6" /> says <input type="text" name="msg" value="" id="msg" size="40" />
    <input type="submit" style='display:none' />
    </form>
  </body>
</html>