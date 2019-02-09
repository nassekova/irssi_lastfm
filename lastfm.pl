
# lastfm.pl -- last.fm now playing script for irssi
# Patroklos Argyroudis, argp at domain sysc.tl
# Fixe to work in 2019 by Niko Runtti.

use strict;
use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind active_win);
use LWP::UserAgent;
use utf8;
#use XML::Simple;
#use Data::Dumper;

$VERSION = '0.3';

%IRSSI =
(
    authors     => 'Niko Runtti',
    contact     => 'nassekova@gmail.com',
    name        => 'last.fm now playing',
    description => 'polls last.fm and displays the most recent audioscrobbled track',
    license     => 'BSD',
    url         => 'https://github.com/nassekova/irssi_lastfm.git',
    changed     => '2019',
    commands    => 'lastfm np',
);

my $timeout_seconds = 120;
my $timeout_flag;
my $np_username = '';
my $username;
my $cached;
my $proxy_str = '';
my @channels;

sub show_help()
{
    my $help = "lastfm $VERSION
/lastfm start <username>
    start a last.fm now playing session
/lastfm stop
    stop the active last.fm now playing session
/lastfm timeout <seconds>
    specify the polling timeout in seconds (default: 120),
    be careful when changing the default value, too
    aggressive polling may get your IP blacklisted
/lastfm channel <command> [channel name]
    manipulate display channels, command can be add, del or list
/lastfm proxy <hostname> <port>
    set an HTTP proxy (default: none)
/np [username (only required on the first invocation)]
    display the most recent audioscrobbled track in the active window";

    my $text = '';
    
    foreach(split(/\n/, $help))
    {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    
    Irssi::print("$text");
}

sub cmd_lastfm
{
    my ($argv, $server, $dest) = @_;
    my @arg = split(/ /, $argv);
    
    if($arg[0] eq '')
    {
        show_help();
    }
    elsif($arg[0] eq 'timeout')
    {
        if($arg[1] eq '')
        {
            show_help();
        }
        else
        {
            $timeout_seconds = $arg[1];
        }
    }
    elsif($arg[0] eq 'proxy')
    {
        if($arg[1] eq '' || $arg[2] eq '')
        {
            show_help();
        }
        else
        {
            $proxy_str = "$arg[1]:$arg[2]";
            Irssi::print("last.fm HTTP proxy set to http://$proxy_str");
        }
    }
    elsif($arg[0] eq 'channel')
    {
        if($arg[1] eq '')
        {
            show_help();
        }
        elsif($arg[1] eq 'list')
        {
            if(defined($channels[0]))
            {
                Irssi::print("last.fm display channels: @channels");
            }
            else
            {
                Irssi::print('last.fm display channels: none specified');
            }
        }
        elsif($arg[1] eq 'add')
        {
            if($arg[2] eq '')
            {
                show_help();
            }
            else
            {
                push(@channels, $arg[2]);
                Irssi::print("channel $arg[2] added to last.fm display channels");
            }
        }
        elsif($arg[1] eq 'del')
        {
            if($arg[2] eq '')
            {
                show_help();
            }
            else
            {
                my @new_channels = grep(!/$arg[2]/, @channels);
                @channels = ();
                @channels = @new_channels;
                @new_channels = ();
                Irssi::print("channel $arg[2] deleted from the last.fm display channels");
            }
        }
    }
    elsif($arg[0] eq 'help')
    {
        show_help();
    }
    elsif($arg[0] eq 'stop')
    {
        if(defined($timeout_flag))
        {
            Irssi::timeout_remove($timeout_flag);
            $timeout_flag = undef;
            Irssi::print("last.fm now playing session ($username) stopped");
        }
    }
    elsif($arg[0] eq 'start')
    {
        if($arg[1] eq '')
        {
            show_help();
        }
        else
        {
            if(defined($timeout_flag))
            {
                Irssi::timeout_remove($timeout_flag);
                $timeout_flag = undef;
                Irssi::print("previous last.fm now playing session ($username) stopped");
            }
            
            $username = $arg[1];
            
            if($timeout_seconds)
            {
                $timeout_flag = Irssi::timeout_add(($timeout_seconds * 1000), 'lastfm_poll', '');
            }
            
            Irssi::print("last.fm now playing session ($username) started");
            
            if(defined($channels[0]))
            {       
                Irssi::print("last.fm display channels: @channels");
            }   
            else
            {       
                Irssi::print('last.fm only displaying in the active window');
            }
        }
    }
}

sub lastfm_get
{
    my $uname = shift;
    my $lfm_url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=$uname&api_key=809d505e4016209720b5c5870b780f01";
    my $agent = LWP::UserAgent->new();
    $agent->agent('argp\'s last.fm irssi script');

    if($proxy_str ne '')
    {
        $agent->proxy(['http', 'ftp'] => "http://$proxy_str");
    }

    $agent->timeout(60);
    
    my $request = HTTP::Request->new(GET => $lfm_url);
    my $result = $agent->request($request);

    $result->is_success or return;

    my $str = $result->content;
    my @arr = split(/\n/, $str);
    my $new_track = '';
    $new_track = $arr[5]; #oli 6
    my $new_artist = $arr[4];
#$new_track = $new_track =/.*/(.*)/;   
# $new_track = (split '/', $new_track)[4];   
# $new_track =~ s/^[0-9]*,//;
   # $new_track =~ s/\xe2\x80\x93/-/;
    #$xml = new XML::Simple;
    #$nasse = $xml->XMLin($lfm_url);
#	$new_track = "$nasse->{artist} - $nasse->{name}"


#get the artist and song from the XML
$new_track =~ s/%C3%84/ä/g;
$new_track =~ s/%C3%A4/ä/g;
$new_track =~ s/%C3%B6/ö/g;
$new_track =~ s/[+]/ /g;
$new_track =~ s/%27/'/g;
#This removes <name> and </name> tags
$new_track =~ s/<(.*?)>/ /g;
$new_track =~ s/^\s+//;
#xml has few marks in werid strings. this fixes those.
$new_track =~ s/&apos;/'/g;
$new_track  =~ s/&lt;/</g;
$new_track  =~ s/&gt;/>/g;
$new_track  =~ s/&amp;/&/g;
$new_track  =~ s/&quot;/"/g;
#active_win->command("/me biisi: $new_track");
#trim
$new_artist =~ s/%C3%84/  /g;
$new_artist =~ s/%C3%A4/  /g;
$new_artist =~ s/%C3%B6/  /g;
$new_artist =~ s/[+]/ /g;
$new_artist =~ s/%27/'/g;
$new_artist =~ s/<(.*?)>/ /g;
$new_artist =~ s/^\s+//;
#xml has few marks in werid strings. this fixes those.
$new_artist =~ s/&apos;/'/g;
$new_artist =~ s/&lt;/</g;
$new_artist =~ s/&gt;/>/g;
$new_artist =~ s/&amp;/&/g;
$new_artist =~ s/&quot;/"/g;

#remove special characters
$new_track =~ s/[#\-%&\$*+<>()]//g;
$new_artist =~ s/[#\-%&\$*+<>()]//g;
#join together song and artist
my $new_song = join "- ", $new_artist, $new_track;
# I like my announcements in lowercase
$new_song =~ tr/A-Z/a-z/;
    return $new_song;
}

sub cmd_np
{
    my ($argv, $server, $dest) = @_;
    my @arg = split(/ /, $argv);
    my $np_track = '';

    if($arg[0] eq '' and $np_username eq '')
    {
        show_help();
        return;
    }
    elsif($np_username eq '' and $arg[0] ne '')
    {
        $np_username = $arg[0];
    }

    $np_track = lastfm_get($np_username);
    active_win->command("/me np: $np_track");
}

sub lastfm_poll
{
    my $new_track = '';

    $new_track = lastfm_get($username);

    if($cached eq $new_track)
    {
        return;
    }
    else
    {
        if(defined($channels[0]))
        {
            foreach my $chan_name (@channels)
            {
                foreach my $chan (Irssi::channels())
                {
                    if($chan_name eq $chan->{'name'})
                    {
                        $chan->window->command("/me np: $new_track");
                    }
                }
            }
        }
        else
        {
            active_win->command("/me np: $new_track");
        }
  
        $cached = $new_track;
    }
}

Irssi::command_bind('lastfm', 'cmd_lastfm');
Irssi::command_bind('np', 'cmd_np');
Irssi::print("last.fm now playing script v$VERSION, /lastfm help for help");

# EOF
