package MyCGI;

#############################################################################
# CGI interface
#############################################################################

use strict;
use vars qw($VERSION);

use CGI qw(:standard); # import from standard CGI module

$VERSION = 1.0;

###############################################################################
# constructor new: create a handle to data stored in hash; returns 0 if not CGI
###############################################################################

sub new {
# create an instance read object 
    my $prototype = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{cgi_input} = {}; # place holder
    $self->{und_error} = ''; # for error info
    $self->{'header'}  = 0 ; # return header counter

    bless ($self, $class);

    $self->{status} = &ReadParse(0,$self);

    return $self;
}

###############################################################################
# input string parser
###############################################################################

sub ReadParse {
# private function
    my $lock  = shift;
    my $self  = shift;

    die "You're not supposed to invoke this method\n" if $lock;

    my ($in, @in, %in);
    my ($i, $loc, $key, $val);

    if ($ENV{REQUEST_METHOD}) {
        if ($ENV{REQUEST_METHOD} eq "GET") {
            $in = $ENV{QUERY_STRING};
        }
        elsif ($ENV{REQUEST_METHOD} eq "POST") {
            my $length = $ENV{CONTENT_LENGTH};
            read (STDIN, $in, $length);
        }
        else {
            $self->{error} = "Invalid request method $ENV{REQUEST_METHOD}";
            return 0;
        }
    }
    else {
        return 0;
    }

# okay, $in contains the input string, get into array @in

    @in = split(/&/,$in) if defined($in);
    foreach $i (0 .. $#in) {

        $in[$i] =~ s/\+/ /g;

       ($key,$val) = split (/=/,$in[$i],2); # splits on the first =
        $val = '' if !defined($val);

        $key =~ s/%(..)/pack("c",hex($1))/ge;
        $val =~ s/%(..)/pack("c",hex($1))/ge;

        $in{$key} .= "\0" if (defined($in{$key})); # \0 is separator
        $in{$key} .= $val; # \0 separator allows for multiple values
    }

# store reference to %in in $self hash 

    $self->{cgi_input} = \%in;

    return 1;
}

###############################################################################
# request method determination
###############################################################################

sub MethodGet {
    return ($ENV{REQUEST_METHOD} eq "GET");
}


sub MethodPost {
    return ($ENV{REQUEST_METHOD} eq "POST");
}

#----------------------------------------------------------------------------

sub ReDirect {
# print redirect string; must come before any other output of a script
    my $self = shift;
    my $link = shift;

#$self->PrintHeader(1); print "redirecting to url $link \n";

    $link .= $self->postToGet if ($link !~ /\?/); # if &MethodPost; # add (possible) parameters

# $link .= "\&EJZREDIRECT=1"; $link =~ s/\&/?/ if ($link !~ /\?/); # test for redirection

    print redirect(-location=>$link);

    exit 0;
}

###############################################################################
# return header string
###############################################################################

sub PrintHeader {
    my $self = shift;
    my $type = shift;

    return if $self->{'header'};

    $type = 0 if !defined($type);
    print STDOUT "content-type: text/html\n\n" if !$type; # default response
    print STDOUT "content-type: text/plain\n\n" if $type;

    $self->{'header'} = 1 + $type; # 1 for HTML, 2 for plain
}

###############################################################################
# output key-value pairs
###############################################################################

sub parameter {
# return value of given key and keep track of undefined input
    my $self = shift;
    my $key  = shift;
    my $test = shift;

    my $in = $self->{cgi_input};

    if ((!defined($test) || $test) && (!defined($in->{$key}) || $in->{$key} !~ /\S/)) {
        delete $in->{$key} if $in->{$key};
        $self->{und_error} .= "$key ";
    }

    return $in->{$key};
}

###############################################################################

sub transport {
# pass the current cgi value as hidden fields to an HTML form
    my $self = shift;
    my $page = shift;

    my $in = $self->{cgi_input};
    foreach my $key (keys (%$in)) {
        $page->hidden($key,$in->{$key}) if ($in->{$key});
    }
}

###############################################################################

sub postToGet {
# convert posted CGI parameters/values into a get formatted string
    my $self = shift;
    my $type = shift;

# a list of parameter/values to be excluded can be provided as array

    if (!defined($type)) {
        $type = -1;
    }
    elsif ($type != 0 && $type != 1) {
        return "Invalid type specification in postToGet";
    }

    my %inexclude;
    while (@_) {
        my $name = shift;
        $inexclude{$name}++;
    }

    my $string = '';
    my $in = $self->{cgi_input};
    foreach my $key (keys (%$in)) {
        my $accept = 1;
        $accept = 0 if ($key eq 'submit'); # always
        $accept = 0 if ($key eq 'confirm'); # always
        $accept = 0 if ($type == 0 &&  $inexclude{$key}); # key in exclude list
        $accept = 0 if ($type >= 1 && !$inexclude{$key}); # key not in include list
        if ($accept && $in->{$key} =~ /\w/) {
            $string .= "\&" if ($string =~ /\w/);
            $string .= "\?" if ($string !~ /\S/);
            $string .= "$key=$in->{$key}";
        } 
    }
    $string =~ s/\s//g;
    return $string;
}

###############################################################################

sub delete {
# delete a key
    my $self = shift;
    my $key  = shift;
    my $test = shift; # deletes values of 'tag' format <*****>

    if ($test && defined($self->{cgi_input}->{$key})) {
        return ($self->{cgi_input}->{$key} =~ s/^\<.*\>$//);
    }
    else {
        return transpose ($self,$key);
    }
}

#------------------------------------------------------------------------------

sub transpose {
# rename or delete a key in the input data
    my $self  = shift;
    my $okey  = shift;
    my $nkey  = shift; # delete entry $okey if $nkey is missing
    my $force = shift;

    my $status = 0;
    my $in = $self->{cgi_input};

    if (defined($okey) && defined($in->{$okey})) {

        if (defined($nkey) && (!defined($in->{$nkey})|| $force)) {
            $in->{$nkey} = $in->{$okey};
            $status++;
        }
	delete $in->{$okey};
        $status++;
    }

# output status 0 for nothing done, 1 for delete of $okey, 2 for rename

    return $status; 
}

#------------------------------------------------------------------------------

sub replace {
# replace or append a key's value or add a new one
    my $self   = shift;
    my $key    = shift;
    my $value  = shift;
    my $append = shift;

    return if (!defined($key) || !defined($value));

    my $in = $self->{cgi_input};

    $append = 0 if (!$append || !defined($in->{$key}));

    $in->{$key} = $value if (!$append);
    $in->{$key} .= $value if ($append);
}

#------------------------------------------------------------------------------

sub addkey {
# add a key and value to the %in buffer
    my $self   = shift;
    my $key    = shift;
    my $value  = shift;

    &replace($self,$key,$value);
}

###############################################################################

sub hash {
# return the reference to cgi_input hash itself
    my $self = shift;

    return $self->{cgi_input};
}

###############################################################################

sub PrintVariables {
# print variables
    my $self = shift;
    my $show = shift;

    my $in = $self->{cgi_input};

    my $output;
    if (keys (%$in)) {

        $output = "<TABLE BORDER=1 CELLPADDING=2>";
        $output .= "<TR><TH>CGI parameter</TH><TH>Value</TH></TR>";

        foreach my $key (sort keys (%$in)) {
            my $value = "&nbsp";
            $value = $in->{$key} if (defined($in->{$key}) && $in->{$key} =~ /\S/);
            $value =~ s/\<|\>//g; # remove HTML tag boundaries to avoid confusion
            $value =~ s/\0/ & /g; # allow multiple definitions 
            $output .= "<TR><TD>$key</TD><TD>$value</TD></TR>";
        }
        $output .= "</TABLE>";

    } else {

        $output = "<h4>There is no CGI input</h4>";

    }

    $output .= "<P>";

    if ($self->{'header'} != 1) {
        $output =~ s/\<\/tr\>|\<p\>/\n/ig; # replace line tags by line break
        $output =~ s/\<[^\<\>]+\>/ /g; # remove all other tags
    }

    print STDOUT "$output\n" if ($show);

    return $output;
}

###############################################################################

sub PrintEnvironment {
# print variables
    my $self = shift;
    my $show = shift;

    my $output;
    if (keys (%ENV)) {

        $output = "<TABLE BORDER=1 CELLPADDING=2>";
        $output .= "<TR><TH>ENV parameter</TH><TH>Value</TH></TR>";

        foreach my $key (sort keys (%ENV)) {
            my $value = "&nbsp";
            $value = $ENV{$key} if ($ENV{$key}  && $ENV{$key} =~ /\S/);
            $output .= "<TR><TD>$key</TD><TD>$value</TD></TR>";
        }
        $output .= "</TABLE>";

    } else {

        $output = "<h4>There is no ENV input</h4>";

    }

    $output .= "<P>";

    print STDOUT "$output\n" if ($show);

    return $output;
}

###############################################################################

sub ShortList {
    my $self = shift;
    my $show = shift;
    my $hash = shift;

    $hash = $self->{cgi_input} if !$hash;

    undef my $output;

    if (keys (%$hash)) {
        my $out;
        foreach my $key (sort keys(%$hash)) {
            if (($out = $hash->{$key}) =~ s/\n/<BR>/g) {
                $output .= "<DL COMPACT><DT><B>$key</B>is<DD><i>$out</i></DL>";
            } else {
                $output .= "<B>$key</b>is<I>$out</I><BR>";
            }
        }
    } else {

        $output = "<h4>There is no CGI input</h4>";

    } 

    $output .= "<P>";

    print STDOUT "$output\n" if ($show);

    return $output; 
}

###############################################################################
# encryption
###############################################################################

sub ShortEncrypt {
# encrypt a short, up to 8 characters, $word, usinf $name as part of seed
    my $self = shift;
    my $word = shift;
    my $name = shift;

    return 0 if (!defined($name) || !defined($word) || !$name || !$word); 

    my $in = $self->{in};

# if $word is one of the $in keys, encrypt the value

    $word = $in->{$word} if (defined($in->{$word}));

# truncate at 8 characters

    $word = substr($word,0,8) if (length($word) > 8);

# okay, get the seed from the time and the $name

    my @seedset = ('a'..'z','A'..'Z','0'..'9','.','_');
    my $now = time;
    my ($pert1,$pert2) = unpack("C2",$name);
    $pert1 = 0 if (!$pert1); $pert2 = 0 if (!$pert2);
    my $week = $now/(60*60*24*7) + $pert1 + $pert2;
    my $seed = $seedset[$week % 64] . $seedset[$now % 64];

# and encrypt

    my $encrypt = crypt ($word,$seed);

    return $encrypt;
}

###############################################################################

sub VerifyEncrypt {
# test a password against its encrypted version
    my $self     = shift;
    my $password = shift;
    my $encrypt  = shift;

# encrypting the password using encrypt as seed should return the seed

    my $inverse = 0;
    $inverse = crypt ($password,$encrypt) if ($password && $encrypt);
#print "Verify: password=$password  encrypt=$encrypt  inverse=$inverse<br>";
    $inverse = 0 if ($encrypt && $inverse ne $encrypt);
    
    return $inverse; # 0 if no match
}

###############################################################################
#sub LongEncrypt {
#}
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.0 ,
        date    =>    "30 Apr 2001",
        update  =>    "09 May 2002",
    };
}

###############################################################################

1;
