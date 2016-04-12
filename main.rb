require "socket"
require "proxifier"
require "json"
require "yaml"
require "terminal-table"
# Don't allow use of "tainted" data by potentially dangerous operations
$SAFE=1
$report = []
def load_config()
    data = JSON.parse(YAML.load_file("./config.yml").to_json, symbolize_names: true)
    @servers = data[:servers]
    @name = data[:bot_name]
    @channel = data[:channel]
end
# The irc class, which talks to the server and holds the main event loop
class IRC
    def initialize(server, port, nick, channel)
        @server = server
        @port = port
        @nick = nick
        @channel = channel
    end
    def send(s)
        # Send a message to the irc server and print it to the screen
        #puts "--> #{s}"
        @irc.send "#{s}\n", 0
    end
    def connect()
        proxy = Proxifier::Proxy("socks://localhost:9050")
        # Connect to the IRC server
        puts "[INFO]Try connect to server #{@server}:#{@port}"
        @irc = proxy.open(@server, @port)
        send "USER blah blah blah :blah blah"
        send "NICK #{@nick}"
    end
    def evaluate(s)
        # Make sure we have a valid expression (for security reasons), and
        # evaluate it if we do, otherwise return an error message
        if s =~ /^[-+*\/\d\s\eE.()]*$/ then
            begin
                s.untaint
                return eval(s).to_s
            rescue Exception => detail
                puts detail.message()
            end
        end
        return "Error"
    end
    def handle_server_input(s)
        # This isn't at all efficient, but it shows what we can do with Ruby
        # (Dave Thomas calls this construct "a multiway if on steroids")
        case s.strip
            when /^PING :(.+)$/i
                if @ping
                    $report << [@server, "OK"]
                    @stop = true
                else
                    @ping = true
                end
                #puts "[ Server ping ]"
                send "PONG :#{$1}"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i
                #puts "[ CTCP PING from #{$1}!#{$2}@#{$3} ]"
                send "NOTICE #{$1} :\001PING #{$4}\001"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i
                #puts "[ CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
                send "NOTICE #{$1} :\001VERSION Ruby-irc v0.042\001"
            when /^(.+?):End of \/MOTD command/i
                send "INFO"
            when /^:(.+?)\/INFO/i
                $report << [@server, "OK"]
                @stop = true
            when /^(.+?):Nickname is already in use/i
                send "NICK #{@nick}_#{Time.now.to_i.to_s.split(//).last(3).join}"
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:EVAL (.+)$/i
                #puts "[ EVAL #{$5} from #{$1}!#{$2}@#{$3} ]"
                send "PRIVMSG #{(($4==@nick)?$1:$4)} :#{evaluate($5)}"
            when /^ERROR /i
                $report << [@server, s]
            else
                #puts s
        end
    end
    def main_loop()
        # Just keep on truckin' until we disconnect
        while !@stop
            ready = select([@irc, $stdin], nil, nil, nil)
            next if !ready
            for s in ready[0]
                if s == $stdin then
                    return if $stdin.eof
                    s = $stdin.gets
                    send s
                elsif s == @irc then
                    return if @irc.eof
                    s = @irc.gets
                    handle_server_input(s)
                end
            end
        end
    end
end

load_config();
@servers.each do |server|
    begin
        adrs = server.split(":")
        irc = IRC.new(adrs[0], adrs[1]? adrs[1].to_i : 6667, @name, @channel)
        irc.connect()
        irc.main_loop()
    rescue Interrupt
    rescue Exception => detail
        $report << [server, detail.message()]
        next
    end
end

$stdout.reopen("report.txt","w")
$report.each do |row|
    puts "[HOST]#{row[0]}"+" "*(50-row[0].length)+"[STATUS]#{row[1]}"
end
