# Perl Routines to Manipulate CGI input
# S.E.Brenner@bioc.cam.ac.uk
# $Id: cgi-lib.pl,v 1.1.1.1 2002-05-28 12:28:13 ejz Exp $
#
# Copyright (c) 1996 Steven E. Brenner  
# Unpublished work.
# Permission granted to use and modify this library so long as the
# copyright above is maintained, modifications are documented, and
# credit is given for any use of the library.
#
# Thanks are due to many people for reporting bugs and suggestions
# especially Meng Weng Wong, Maki Watanabe, Bo Frese Rasmussen,
# Andrew Dalke, Mark-Jason Dominus, Dave Dittrich, Jason Mathews

# For more information, see:
#     http://www.bio.cam.ac.uk/cgi-lib/


# Parameters affecting cgi-lib behavior
$cgi_lib'maxdata = 131072;   # maximum bytes to accept via POST - 2^17
$cgi_lib'bufsize =  8192;    # default buffer size when reading multipart
$cgi_lib'maxbound = 100;     # maximum boundary length to be encounterd
$cgi_lib'writefiles = 0;     # directory to which to write files

# ReadParse
# Reads in GET or POST data, converts it to unescaped text, and puts
# key/value pairs in %in, using '\0' to separate multiple selections

# Returns TRUE if there was input, FALSE if there was no input 
# UNDEF may be used in the future to indicate some failure.

# Now that cgi scripts can be put in the normal file space, it is useful
# to combine both the form and the script in one place.  If no parameters
# are given (i.e., ReadParse returns FALSE), then a form could be output.

# If a variable-glob parameter (e.g., *cgi_input) is passed to ReadParse,
# information is stored there, rather than in $in, @in, and %in.

sub ReadParse {
  local (*in) = @_ if @_;
  local ($len, $type, $meth);

  # Get several useful env variables
  $type = $ENV{'CONTENT_TYPE'};
  $len = $ENV{'CONTENT_LENGTH'};
  $meth = $ENV{'REQUEST_METHOD'};

  if ($len > $cgi_lib'maxdata) {
      &CgiDie("cgi-lib.pl: Request to receive too much data: $len bytes\n");
  }

  if ($type eq 'application/x-www-form-urlencoded' || $type eq '' ) {
    local ($key, $val, $i);

    # Read in text
    if ($meth eq 'GET') {
      $in = $ENV{'QUERY_STRING'};
    } elsif ($meth eq 'POST') {
        read(STDIN, $in, $len);
    } else {
      &CgiDie("cgi-lib.pl: Unknown request method: $meth\n");
    }

    @in = split(/[&;]/,$in); 

    foreach $i (0 .. $#in) {
      # Convert plus to space
      $in[$i] =~ s/\+/ /g;

      # Split into key and value.  
      ($key, $val) = split(/=/,$in[$i],2); # splits on the first =.

      # Convert %XX from hex numbers to alphanumeric
      $key =~ s/%(..)/pack("c",hex($1))/ge;
      $val =~ s/%(..)/pack("c",hex($1))/ge;

      # Associate key and value
      $in{$key} .= "\0" if (defined($in{$key})); # \0 is the multiple separator
      $in{$key} .= $val;
    }

  } elsif ($ENV{'CONTENT_TYPE'} =~ m#^multipart/form-data#) {
    # for efficiency, compile multipart code only if needed
eval <<'END_MULTIPART';
{
    local ($buf, $boundary, $head, $blen);
    local ($bpos, $lpos, $left, $amt, $fn, $ser);
    local ($bufsize, $maxbound, $writefiles) = 
      ($cgi_lib'bufsize, $cgi_lib'maxbound, $cgi_lib'writefiles);

    ($boundary) = $type =~ /boundary="([^"]+)"/; #";   # find boundary
    ($boundary) = $type =~ /boundary=(\S+)/ unless $boundary;
    &CgiDie ("Boundary not provided") unless $boundary;
    $boundary =  "--" . $boundary;
    $blen = length ($boundary);

    if ($ENV{'REQUEST_METHOD'} ne 'POST') {
      &CgiDie("Invalid request method for  multipart/form-data: $meth\n");
    }

    if ($writefiles) {
      local($me);
      stat ($writefiles);
      $writefiles = "/tmp" unless  -d _ && -r _ && -w _;
      ($me) = $0 =~ m#([^/]*)$#;
      $writefiles = "$writefiles/$me";
    }

    # read in the data and split into parts:
    # put headers in @in and data in %in
    # General algorithm:
    #   There are two dividers: the border and the '\r\n\r\n' between
    # header and body.  Iterate between searching for these
    #   Retain a buffer of size(bufsize+maxbound); the latter part is
    # to ensure that dividers don't get lost by wrapping between two bufs
    #   Look for a divider in the current batch.  If not found, then
    # save all of bufsize, move the maxbound extra buffer to the front of
    # the buffer, and read in a new bufsize bytes.  If a divider is found,
    # save everything up to the divider.  Then empty the buffer of everything
    # up to the end of the divider.  Refill buffer to bufsize+maxbound
    #   Note slightly odd organization.  Code before BODY: really goes with
    # code following HEAD:, but is put first to 'pre-fill' buffers.  BODY:
    # is placed before HEAD: because we first need to discard any 'preface,'
    # which would be analagous to a body without a preceeding head.

    $left = $len;
   PART: # find each part of the multi-part while reading data
    while (1) {
      $amt = ($left > $bufsize+$maxbound-length($buf) 
	      ?  $bufsize+$maxbound-length($buf): $left);
      read(STDIN, $buf, $amt, length($buf));
      $left -= $amt;

      $in{$name} .= "\0" if defined $in{$name}; 
      $in{$name} .= $fn if $fn;
     BODY: 
      while (($bpos = index($buf, $boundary)) == -1) {
        if ($name) {  # if no $name, then it's the prologe -- discard
          if ($fn) { print FILE substr($buf, 0, $bufsize); }
          else     { $in{$name} .= substr($buf, 0, $bufsize); }
        }
        $buf = substr($buf, $bufsize);
        $amt = ($left > $bufsize ? $bufsize : $left);
        read(STDIN, $buf, $amt, $maxbound);  # $maxbound == length($buf);
        $left -= $amt;
      }
      if (defined $name) {  # if no $name, then it's the prologe -- discard
        if ($fn) { print FILE substr($buf, 0, $bpos-2); }
        else     { $in {$name} .= substr($buf, 0, $bpos-2); } # kill last \r\n
      }
      close (FILE);
      last PART if substr($buf, $bpos + $blen, 4) eq "--\r\n";
      substr($buf, 0, $bpos+$blen+2) = undef;
      $amt = ($left > $bufsize+$maxbound-length($buf) 
	      ? $bufsize+$maxbound-length($buf) : $left);
      read(STDIN, $buf, $amt, length($buf));
      $left -= $amt;


      undef $head;  undef $fn;
     HEAD:
      while (($lpos = index($buf, "\r\n\r\n")) == -1) { 
        $head .= substr($buf, 0, $bufsize);
        $buf = substr($buf, $bufsize);
        $amt = ($left > $bufsize ? $bufsize : $left);
        read(STDIN, $buf, $amt, $maxbound);  # $maxbound == length($buf);
        $left -= $amt;
      }
      $head .= substr($buf, 0, $lpos+2);
      push (@in, $head);
      ($name) = $head =~ /name="([^"]+)"/; #"; 
      ($name) = $head =~ /name=(\S+)/ unless $name;  
      if ($writefiles && $head =~ /filename=/) {
        $ser++;
	$fn = $writefiles . ".$$.$ser";
	open (FILE, ">$fn") || &CgiDie("Couldn't open $fn\n");
      }
      substr($buf, 0, $lpos+4) = undef;
    }

}
END_MULTIPART
  } else {
    &CgiDie("cgi-lib.pl: Unknown Content-type: $ENV{'CONTENT_TYPE'}\n");
  }

  return scalar(@in); 
}


# PrintHeader
# Returns the magic line which tells WWW that we're an HTML document

sub PrintHeader {
  return "Content-type: text/html\n\n";
}


# HtmlTop
# Returns the <head> of a document and the beginning of the body
# with the title and a body <h1> header as specified by the parameter

sub HtmlTop
{
  local ($title) = @_;

  return <<END_OF_TEXT;
<html>
<head>
<title>$title</title>
</head>
<body>
<h1>$title</h1>
END_OF_TEXT
}

# Html Bot
# Returns the </body>, </html> codes for the bottom of every HTML page

sub HtmlBot
{
   return "</body>\n</html>\n";
 }


# MethGet
# Return true if this cgi call was using the GET request, false otherwise

sub MethGet {
  return ($ENV{'REQUEST_METHOD'} eq "GET");
}


# MethPost
# Return true if this cgi call was using the POST request, false otherwise

sub MethPost {
  return ($ENV{'REQUEST_METHOD'} eq "POST");
}


# MyURL
# Returns a URL to the script

sub MyURL  {
  local ($port);
  $port = ":" . $ENV{'SERVER_PORT'} if  $ENV{'SERVER_PORT'} != 80;
  return  'http://' . $ENV{'SERVER_NAME'} .  $port . $ENV{'SCRIPT_NAME'};
}


# CgiError
# Prints out an error message which which containes appropriate headers,
# markup, etcetera.
# Parameters:
#  If no parameters, gives a generic error message
#  Otherwise, the first parameter will be the title and the rest will 
#  be given as different paragraphs of the body

sub CgiError {
  local (@msg) = @_;
  local ($i,$name);

  if (!@msg) {
    $name = &MyURL;
    @msg = ("Error: script $name encountered fatal error");
  };

  print &PrintHeader;
  print "<html><head><title>$msg[0]</title></head>\n";
  print "<body><h1>$msg[0]</h1>\n";
  foreach $i (1 .. $#msg) {
    print "<p>$msg[$i]</p>\n";
  }
  print "</body></html>\n";
}


# CgiDie
# Identical to CgiError, but also quits with the passed error message.

sub CgiDie {
  local (@msg) = @_;
  &CgiError (@msg);
  die @msg;
}


# PrintVariables
# Nicely formats variables in an associative array passed as a parameter
# And returns the HTML string.
sub PrintVariables {
  local (%in) = @_;
  local ($out, $output);
  $output .=  "\n<dl compact>\n";
  foreach $key (sort keys(%in)) {
    foreach (split("\0", $in{$key})) {
      ($out = $_) =~ s/\n/<br>\n/g;
      $output .=  "<dt><b>$key</b>\n <dd>:<i>$out</i>:<br>\n";
    }
  }
  $output .=  "</dl>\n";

  return $output;
}

# PrintEnv
# Nicely formats all environment variables and returns HTML string
sub PrintEnv {
  local ($var, $output);

  $output = "\n<dl compact>\n";
  foreach $var (sort keys %ENV) {
    $output .= "<dt><b>$var</b>\n <dd><i>$ENV{$var}</i><br>\n";
  }
  $output .= "</dl>\n";
  return $output;
}

1; #return true 

