package MyHTML;

#############################################################################
#
# HTML form handler
#
#############################################################################

use strict;

use MyCGI;

use vars qw($VERSION @ISA);

@ISA = qw(MyCGI);

$VERSION = 1.0;

###############################################################################
# constructor new: create a handle to a new HTML form
###############################################################################

sub new {
# create an instance read object 
    my $caller = shift;
    my $title  = shift;

    my $class = ref($caller) || $caller;
    my $self  = $class->SUPER::new();

    &openPage($self,$title) if $title;

    return $self;
}

###############################################################################

sub openPage {
# open the HTML page
    my $self  = shift;
    my $title = shift;

    $self->{title}   = $title if ($title);

    $self->{content} = []; # array of partitions content
    $self->{current} =  1; # default number of the current partition
    $self->{maximum} =  1; # default number of partitions

    $self->{content}->[0] = ''; # initialize base partition

    return $self;
}

###############################################################################

sub pageExists {
# return true if a page has been opened
    my $self = shift;

    return $self->{content};
}

###############################################################################

sub partition {
# select another partition (nrs 1, 2, 3, .... etc)
    my $self = shift;
    my $part = shift;

    $self->{current} = $part if ($part > 0); 
}

###############################################################################

sub patience {
# print a patience message immediately when invoked
    my $self = shift;
    my $font = shift;

    my $string = "Please be patient .... this can take some time!";
    $string = "<font size=+$font color='white'> $string </font>" if $font;
    print STDOUT "<TABLE align=center><TR><TD>$string</TD></TR></TABLE>\n";

    return 1;
}

###############################################################################

sub title {
# (re)define page title to be displayed on top of the browser
    my $self  = shift;
    my $title = shift;

    $self->{title} = $title if ($title);     
}

###############################################################################

sub form {
# add form instruction and submit link
    my $self   = shift;
    my $link   = shift;
    my $post   = shift;
    my $target = shift;

    my $part = $self->{current} - 1;
    my $content = $self->{content}; #  partition contents

    $post = "POST" if (!$post); # default

# determine if this page already has a form instruction
# if it has, replace the existing form instruction by the new one
# form without defined action closes the form on the page
    

    if ($link) {
        my $formtag = "<FORM action=\"$link\" method=\"$post\">";
        $formtag =~ s/\>/ target="$target">/ if $target;
        if (!($content->[$part] =~ s/\<FORM[^\>]+\>/$formtag/)) {
            $content->[$part] .= "$formtag";
        }
    } else {
        $content->[$part] .= "</FORM>" if ($content->[$part] =~ /\<FORM/);
    }
}

###############################################################################

sub substitute {
# replace a string in the current partition
    my $self   = shift;
    my $target = shift || return;
    my $change = shift || '';
 
    my $part = $self->{current} - 1;
    my $content = $self->{content}; #  partition contents

    $content->[$part] =~ s/$target/$change/;
}

###############################################################################

sub submitbuttonbar {
# add submit button and: a reset button or a return link below or nothing
    my $self  = shift;
    my $reset = shift;
    my $line  = shift;
    my $jump  = shift;
    my $text  = shift;

    my $buttonbar = "<TABLE><TR>";
    $buttonbar .= "<TD ALIGN=LEFT WIDTH=50%><INPUT type='submit' name=";
    $buttonbar .= "'submit' value='&nbsp Submit &nbsp'></TD>";
    if (defined($reset) && $reset eq '1') {
        $buttonbar .= "<TD WIDTH=50% ALIGN=CENTER><INPUT type='reset' value='&nbsp Reset &nbsp'></TD>";
    }
    elsif (defined($reset) && $reset =~ /\w/ && $reset =~ /\D/) {
# require text
        if (!defined($jump) || $jump) {
            $buttonbar .= "</TR><TR><TD ALIGN='CENTER'>or</TD></TR><TR>";
        }
        $text = "RETURN" if (!$text);
        $buttonbar .= "<TD ALIGN='CENTER'><A href=\"$reset\"> $text </A></TD>";
    }
    $buttonbar .= "</TR></TABLE>";
 
    add($self,$buttonbar,0,$line);
}


###############################################################################

sub buttonbartemplate {
# generate a button bar template with a 'number' of buttons
    my $self   = shift;
    my $number = shift;
    my $line   = shift;
    my $values = shift; # reference to array with button specifications 

    my $counter = 0;
    undef my $width; $width = 100/$number if ($number);
    my $buttonbar = "<TABLE><TR>";
    for (my $i=1 ; $i <= $number ; $i++) {
	my $button = "BUTTON$i"; # default placeholder
        $button = $values->[$i-1] if ($values && $i <= @$values);
        $buttonbar .= "<TD WIDTH=$width\%><INPUT $button></TD>";
    }
    $buttonbar .= "</TR></TABLE>";

    add ($self,$buttonbar,0,$line) if ($number>0);
}

###############################################################################

sub confirmbuttonbar {
# add confirm/submit button and a reject field if a return link is given   
    my $self   = shift;
    my $link   = shift;
    my $line   = shift;
    my $colour = shift;

    $colour = "lightgreen" if !$colour;
    my $buttonbar = "<TABLE ALIGN=CENTER><TR>";
    $buttonbar .= "<TD WIDTH=50% bgcolor=\"$colour\" ALIGN=CENTER>";
    $buttonbar .= "<INPUT name='confirm' type='submit' value='CONFIRM'></TD>";
    if (defined($link) && $link) {
        $buttonbar .= "<TD WIDTH=50% ALIGN=CENTER>";
        $buttonbar .= "<A href=\"$link\">REJECT</A></TD>";
    }
    $buttonbar .= "</TR></TABLE>";

    add($self,$buttonbar,0,$line);
}

###############################################################################

sub linkbutton {
# add link field "button"   
    my $self = shift;
    my $text = shift;
    my $link = shift;
    my $line = shift;
    my $colour = shift;

    $colour = "lightgreen" if !$colour;

    my $button = "<TABLE BORDER=1><TR>";
    $button .= "<TD bgcolor=\"$colour\">";
    if ($link =~ /\//) {
    # the link value specifies a url
        $button .= "<A href=\"$link\">&nbsp $text &nbsp </A></TD>";
    } else {
    # use a submit button
        $button .= "<INPUT TYPE='submit' VALUE='&nbsp $text &nbsp'>";
    }
    $button .= "</TR></TABLE>";
    $button .= "<BR>";

    add ($self,$button,0,$line);
}

###############################################################################

sub errorbox {
# format an error message
    my $self = shift;
    my $text = shift;
    my $link = shift;
    my $ltxt = shift;
    my $colour = shift;

    my $part = $self->{current} - 1;
    my $content = $self->{content}; #  partition contents

    undef my $error;
    $colour = 'FFCA88' if (!$colour); # light orange
    $text = "unspecified error" if (!$text);
    $text =~ s/\n/<br>/g;
    $error .= "<TABLE ALIGN=CENTER><TR><TD VALIGN='center' BGCOLOR=\"$colour\">";
    $error .= "<H3>$text</H3></TD></TR></TABLE>";
    if ($link) {
        $ltxt = "GO BACK" if (!$ltxt);
        $error .= "<HR><TABLE ALIGN=CENTER><TR>";
        $error .= "<TD WIDTH=200 ALIGN=CENTER><A href=\"$link\">$ltxt</A></TD>";
        $error .= "</TR></TABLE>";
    }
 
    $content->[$part] .= $error;
}

###############################################################################

sub promptbox {
# display a prompt box
    my $self   = shift;
    my $text   = shift; # the text to be displayed
    my $action = shift; # link to confirm the action
    my $reject = shift; # return link if rejected

    form($self,$action) if ($action);
    center($self,1);
    sectionheader($self,$text,4,1) if ($text);
    confirmbuttonbar($self,$reject,1);
    center($self,0);
}

###############################################################################

sub message {
# display a message in a coloured field
    my $self   = shift;
    my $text   = shift || 'No Message Provided';
    my $colour = shift || 'white';
    my $font   = shift;
    my $center = shift || 0;
    my $twidth = shift || 0;
    my $extra  = shift || '';

    my $part = $self->{current} - 1;
    my $content = $self->{content};

    $text =~ s/\n/<br>/g;
    $text = "<font $font>$text</font>" if $font;
    my $align = ''; $align = "align=center" if $center;
    my $width = ''; $width = "width=$twidth" if $twidth;
    $extra = "<td>$extra</td>" if $extra;
    my $message = "<TABLE $width><TR><TD BGCOLOR=\"$colour\" $align>$text</TD>$extra</TR></TABLE>";

    $content->[$part] .= $message;
}

###############################################################################

sub messagebox {
# display a prompt box
    my $self   = shift;
    my $text   = shift; # the text to be displayed
    my $link   = shift; # the continuation link
    my $line   = shift; # line
    my $colour = shift;

    my $part = $self->{current} - 1;
    my $content = $self->{content}; #  partition contents

    $text = "Please provide a message" if (!$text);

    center($self,1);
    $colour = "lightyellow" if (!$colour);
    my $message = "<TABLE><TR><TD BGCOLOR=\"$colour\">";
    $message   .= "$text</TD></TR></TABLE>";
    $content->[$part] .= $message  if ($text);
    
    $link = ' ' if (!$link);
    my $return = "<p><TABLE><TR><TD BGCOLOR=\"yellow\"><A href=\"$link\">";
    $return .= "CONTINUE</A></TD></TR></TABLE>";
    $return .= "<HR>" if (!defined($line) || $line >= 0);
    $content->[$part] .= $return  if ($link =~ /\w/);
    center($self,0);

    hline($self) if ($line);
}

###############################################################################

sub warningbox {
# display a prompt box
    my $self   = shift;
    my $text   = shift;
    my $line   = shift;
    my $colour = shift;
    
    $colour = "yellow" if (!$colour);
    add($self,"<TABLE><TR><TD BGCOLOR=\"$colour\">WARNING!</TD></TR></TABLE>");
    sectionheader($self,$text,4,$line);
}

###############################################################################

sub sectionheader {
# add a line of text in bold format
    my $self = shift;
    my $text = shift; # the text to be displayed
    my $size = shift;
    my $line = shift;

    my $part = $self->{current} - 1;
    my $content = $self->{content}; #  partition contents

    $size = 3 if (!defined($size));

    center($self,1);
    $content->[$part] .= "<BR>" if ($content->[$part]);
    $content->[$part] .= "<H$size>$text</H$size>" if ($text);

    hline($self) if ($line);    
    center($self,0);
}

###############################################################################

sub space {
# add vertical space
    my $self  = shift;
    my $multi = shift;

    $multi = 1 if !defined($multi);
    while ($multi-- > 0) {
        add ($self,'<BR>');
    }
}

###############################################################################

sub hline {
# add a horizontal line
    my $self = shift;

    add ($self,'<HR>');
}

###############################################################################

sub center {
# center or end center (1 or 0)
    my $self  = shift;
    my $on    = shift;

    my $tag = "</CENTER>";
    $tag =~ s/\/// if ($on);
    add($self,$tag);
}

###############################################################################

sub add {
# add to the current partition
    my $self  = shift;
    my $text  = shift || '';
    my $part  = shift; # optional, default the curent part
    my $hline = shift; # optional, default no closing line
    my $font  = shift; # optional, font specification

    $part = $self->{current} if (!defined($part) || $part <= 0);
    my $content = $self->{content}; #  partition contents

    $text =~ s/\n/<br>/g;
#    $text =~ s/banner/$self->{banner}/ if ($text && $self->{banner});
    $text = "<FONT $font>$text</FONT>" if $font;

    $content->[--$part] .= $text if (defined($text));

    $content->[$part] .= "<HR>" if ($hline);
    $content->[$part] .= "<br>" if (defined($hline) && !$hline);   
}

###############################################################################

sub identify {
# add an id and password box to the form
    my $self   = shift;
    my $repeat = shift;
    my $size   = shift;
    my $line   = shift;

    my ($id,$rp) = split //,$repeat;

    $size = 8 if (!$size);
    my $isize = $size;
    $isize = 8 if ($isize > 8); # arcturus upper limit for user ID
    my $psize = $size;

    my $password = 'PASSWORD'; # used if not replaced below
    my $query = "<TABLE ALIGN=CENTER border=0 cellpadding=2><TR>";
    if (defined($id) && $id) {
        $query .= "<TH ALIGN=RIGHT NOWRAP>User ID</TH><TD ALIGN=LEFT NOWRAP>";
        $query .= "<INPUT NAME='identify' SIZE=$isize VALUE=''></TD><TD>&nbsp</TD>";
        $password = 'password'; # default for "identify, password, [pwrepeat]"
    }
    $query .= "<TH ALIGN=RIGHT NOWRAP>Password</TH><TD ALIGN=LEFT NOWRAP>";
    $query .= "<INPUT TYPE=PASSWORD NAME='$password' SIZE=$psize VALUE=''></TD>";
    if (defined($rp) && $rp) {
        $query .= "<TD>&nbsp</TD><TH ALIGN=RIGHT NOWRAP>Type again</TH>";
        $query .= "<TD ALIGN=LEFT NOWRAP>";
        $query .= "<INPUT TYPE=PASSWORD NAME='pwrepeat' SIZE=$psize VALUE=''></TD>";
    }
    $query .= "</TR></TABLE>";

    add($self,$query,0,$line);
}

###############################################################################

sub ingestCGI {
# transfer CGI input values as hidden values to current page (see MyCGI.pm)
    my $self = shift;
    my $type = shift;

# a list of parameter/values to be excluded can be provided as array

    if (!defined($type)) {
        $type = -1;
    }
    elsif ($type !~ /\d/) {
        $type = -1; # deal with deprecated usage with non-numeric parameter
    }
    elsif ($type != 0 && $type != 1) {
        return "Invalid type specification in postToGet";
    }

    my %inexclude;
    while (@_) {
        my $name = shift;
        $inexclude{$name}++;
    }

# import CGI parameters as hidden variables

    my $in = $self->{cgi_input};
    return if (ref($in) ne 'HASH');

    foreach my $key (keys (%$in)) {
        my $accept = 1;
        $accept = 0 if ($key =~ /^(submit|confirm|action|USER)$/i); # always
        $accept = 0 if ($type == 0 &&  $inexclude{$key}); # key in exclude list
        $accept = 0 if ($type == 1 && !$inexclude{$key}); # key not in include list
        $in->{$key} =~ s/\0/ & /g; # replace any '\0' separator by ampersand in blanks 
        hidden($self,$key,$in->{$key}) if $accept;
# print "CGI key $key  $in->{$key}  accept:$accept  type=$type<br>"; 
    }
}

###############################################################################

sub preload {
# preset variables in <INPUT NAME='$name' VALUE='$value'> if VALUE undefined
# this method relies critically on the single or double quotes being used  
    my $self  = shift;
    my $name  = shift;
    my $value = shift;
    my $over  = shift; # True to replace existing values; else ignore

    my $part = $self->{current} - 1;
    my $content = $self->{content};

    my $subs = 0; # count the substitutions

    undef my %input;
    if ($name eq 'cgi_input') {
        my $in = $value->{$name};
        %input = %$in; # copy to local
# print "CGI preload<br>";
    }
    else {
        $input{$name} = $value;
# print "single value $name preload<br>";
    }

# scan the page for <INPUT tags with undefined values for the input parameters

        
    foreach my $name (keys (%input)) {

        if ($content->[$part] =~ /\<\s*(input\s[^\<\>]*?name\s*\=\s*[\'\"]?$name[\'\"]?[^\<\>]*)\>/is) {
            my $original = $1; my $replacement = $1;
            if ($replacement =~ /radio|checkbox/i) {
# it's a button; check it  
                $replacement .= ' checked' if ($replacement !~ /checked/);
            }
# if the tag does not have a value field, add it
            elsif (!($replacement =~ /value/i)) {
                $replacement .= " VALUE='$input{$name}'";
            }
            elsif ($input{$name}) {
        # fill the space after the value field with the preload value
                my $pattern = '[\'\"]\s*[\'\"]|[\'\"]?([^\'\"]+)[\'\"]?';
                $pattern =~ s/\'/\\'/g; # '
                $replacement =~ s/value\s*\=\s*($pattern)/VALUE='$input{$name}' /i;
                my $valuefield = $1;
                $valuefield =~ s/[\'\"]//g; # remove quotes, if any
# print "the replacement: $replacement<br>\n"; # if ($list);
                $replacement = $original if ($valuefield && !$over);
            }
            else {
#		print "undefined value for key $name ($original) <br>\n";
            }
        # now substitute the original string by the new one with values
            $content->[$part] =~ s/$original/$replacement/ if ($replacement ne $original);;
        }
        elsif ($content->[$part] =~ /\<\s*(input\s[^\<\>]*?name\s*\=\s*[\'\"]?$name[\'\"]?)(.*)/is) {
            my $test = $2; # next match relies on quotes around values
            if ($test =~ /.*?(value\s*\=\s*[\'\"]([^\'\"]+?)[\'\"])/is) {
                my $original = $1; my $replacement = $1; my $target = $2;
                $replacement =~ s/$target/$input{$name}/;
                $content->[$part] =~ s/$original/$replacement/ if ($replacement ne $original);;
            }
        }
    }

# here a check on all checkboxes?

    undef %input;
    return $subs;
}

################################################################################

sub hidden {
# add a hidden name/value field
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    undef my $hidden;
    $value = '' if (!defined($value) || $value !~ /\S/);
    $hidden = "<INPUT TYPE=HIDDEN NAME=\'$name\' VALUE=\'$value\'>" if ($name);

    foreach my $part (@{$self->{content}}) {
        undef $hidden if ($part && $part =~ /(name\s*\=\s*[\'\"]?($name)[\'\"]?)[\s\>]/i && $name eq $2);
#print "hidden $name $value kept ($2)<br>"    if ($hidden); 
#print "hidden $name $value deleted ($1)<br>" if (!$hidden);
        last if (!$hidden);
    }

    add ($self,$hidden,0) if ($hidden);
}


###############################################################################

sub tablelist {
# add a table of list items
    my $self  = shift;
    my $list  = shift;
    my $line  = shift;

    my $table = "<TABLE CELLPADDING=2>";
    foreach my $item (@$list) {
        $table .= "<TR><TD>$item</TD></TR>";
    }
    $table .= "</TABLE>";

    add ($self,$table,0,$line) if ($table);
}

###############################################################################

sub choicelist {
# add a SELECT choice list
    my $self = shift;
    my $name = shift; # name of form item
    my $list = shift; # reference to array with values/names
    my $size = shift; # optional width of field                  # ?? non-std HTML ??
    my $line = shift; # continuation line
    my $mark = shift;

# compose HTML select construct

    my $width = ''; # default no width specification
    $width = "width=$size" if ($size && $size > 0);

    my $choice;
    if (ref($list) ne 'ARRAY' || @$list <= 1) {
        $choice = 'No Value Provided';
        $choice = $list if (ref($list) ne 'ARRAY' && defined($list));
        $choice = $list->[0] if (ref($list) eq 'ARRAY' && @$list);
    }
    else {
        my $preselect = '';
        my $select = "SELECTED";
        $choice = "<SELECT $width name = \'$name\'>";
        foreach my $listitem (@$list) {
            $preselect = $select if (!$mark || $mark =~ /\b$listitem\b/); 
            $choice .= "<OPTION value = \'$listitem\' $preselect > $listitem";
            $select = '' if $preselect;
        }
        $choice .= "</SELECT>";
    }

    add ($self,$choice,0,$line) if (!defined($line) || $line >=0) ;

    return $choice;
}

###############################################################################

sub locate {
# return the partition which contents matches the tarcer string 
    my $self   = shift;
    my $tracer = shift;

    my $output = 0;
    if (ref($self->{content}) eq "ARRAY") {
# go through each partition and see if it matches the tracer
        my $counter = 0;
        foreach my $part (@{$self->{content}}) {
            $counter++;
            $output = $counter if ($part && $part =~ /$tracer/);
            last if ($output);
        }
    }
    return $output;
}

###############################################################################

sub arcturusGUI {
# put the partition 0 inside a 
    my $self = shift;
    my $mtop = shift;
    my $side = shift;
    my $bgcolor = shift;

    $mtop = 5   if (!defined($mtop));
    $side = 25  if (!$side);
    $bgcolor = "beige" if (!$bgcolor);

    undef my $layout;
    $layout .= "<TABLE ALIGN=CENTER WIDTH=100% BORDER=0 CELLPADDING=1 CELLSPACING=3><TR>";
    $layout .= "<TD ALIGN=CENTER HEIGHT=$mtop WIDTH=$side BGCOLOR=$bgcolor>ARCTURUSLOGO</TD>";
    $layout .= "<TD HEIGHT=$mtop BGCOLOR=$bgcolor>CON1</TD>";
    $layout .= "<TD ALIGN=CENTER HEIGHT=$mtop WIDTH=$side BGCOLOR=$bgcolor>SANGERLOGO</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON2</TD>";
    $layout .= "<TD ROWSPAN=5 VALIGN=TOP>CON0</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON3</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON4</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON5</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON6</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON7</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON8</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON9</TD>";
    $layout .= "</TR><TR>";
   $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor HEIGHT=0>&nbsp</TD>";
   $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor HEIGHT=0>&nbsp</TD>";
   $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=white VALIGN=TOP>CON10</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=white VALIGN=TOP>CON11</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=white VALIGN=TOP>CON12</TD>";
    $layout .= "</TR></TABLE>";

    $self->{layout} = $layout;
}

###############################################################################

sub frameborder {
# put the partition 0 inside an empty boundary
    my $self = shift;
    my $mtop = shift;
    my $side = shift;
    my $bgcolor = shift;
    my $mbot = shift;

# clear any existing layout

    my $content = $self->{content};
    undef @$content;
    $content->[0] = '';

    $mtop = 5   if (!defined($mtop));
    $side = 15  if (!$side);
    $bgcolor = "white" if (!$bgcolor);
    $mbot = $mtop      if (!defined($mbot));

    undef my $layout;
    $layout .= "<TABLE ALIGN=CENTER WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0>";
    $layout .= "<TR><TD COLSPAN=3 HEIGHT=$mtop BGCOLOR=$bgcolor>CON1</TD></TR>";
    $layout .= "<TR><TD WIDTH=$side\% BGCOLOR=$bgcolor>CON2</TD>";
    $layout .= "<TD VALIGN=TOP>CON0</TD>";
    $layout .= "<TD WIDTH=$side\%  BGCOLOR=$bgcolor>CON3</TD></TR>";
    $layout .= "<TR><TD COLSPAN=3 HEIGHT=$mbot BGCOLOR=$bgcolor align=center>CON4</TD></TR>";
    $layout .= "</TABLE>";

    $self->{layout} = $layout;

# make partition 1 (CON0) the default

    $self->{current} = 1;
    $self->center(1);
}

###############################################################################

sub quartetborder {
# put 4 partitions (nr 0,4,5,6) at the centre of a frameborder layout
    my $self = shift;

    &frameborder($self,@_);
    my $quartet = "<CENTER><TABLE CELLPADDING=5 WIDTH=100%><TR>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON0</TD>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON5</TD>";
    $quartet   .= "</TR><TR VALIGN=TOP>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON6</TD>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON7</TD>";
    $quartet   .= "</TR></TABLE><CENTER>";
    $self->{layout} =~ s/CON0/$quartet/;
}

###############################################################################

sub banner {
    my $self   = shift;
    my $text   = shift;
    my $colour = shift;

    undef $self->{banner};

    $colour = 'orange' if !$colour;

#    $self->{banner} = "<TABLE ALIGN=CENTER><TR><TH bgcolor=$colour><H4>$text</H4></TH></TR></TABLE>";
    $self->{banner} = "<FONT color=$colour size=+1>$text</FONT>";
}

###############################################################################

sub address {
# add a formatted email address for support
    my $self = shift;
    my $mail = shift;
    my $name = shift;
    my $lout = shift || 0; # 0 for nocenter; 1 for center; 2 for no center & line; 3 for center & line
    my $part = shift;

    my $address;
    $address .= "<hr>" if ($lout >= 2);
    $address .= "<center>"  if ($lout == 1 || $lout == 3);
    $address .= "<address>Please send suggestions or problem reports ";
    $address .= "to <a href=\"mailto:$mail\">$name</a></address>";
    $address .= "</center>" if ($lout == 1 || $lout == 3);

    $self->add($address,$part)  if  $part;
    $self->{address} = $address if !$part;
}

###############################################################################

sub flush {
# output the form
    my $self = shift;
    my $null = shift;
    my $list = shift;

    my $title   = $self->{'title'};
    my $content = $self->{'content'} || return 0;
    my $layout  = $self->{'layout'};
    my $address = $self->{'address'};
    my $banner  = $self->{'banner'};

    my $bodyqualifiers = "bgcolor = \"white\"";

    undef my $output;
    $output .= "<HTML><HEAD><TITLE>$title</TITLE></HEAD>";
    $output .= "<BODY $bodyqualifiers>";

    if (defined($layout)) {
        my $blank = "&nbsp";
        foreach (my $i=0 ; $i <= 12 ; $i++) {
# test if the contents element contains any text
            my $hasContent = 0;
            $hasContent = 1 if ($content->[$i] && $content->[$i] =~ /\>[^\<\>\s]+\<|[^\<\>\s]+/);
            $layout =~ s/CON$i/$content->[$i]/ if  $hasContent;
            $layout =~ s/CON$i/$blank/g        if !$hasContent;
        }
        $output .= $layout;
    }
    else {
        $output .= $content->[0];
    }
    $output .= $address if defined($address);
    $output .= "</BODY></HTML>";

# clear the contents

    $null = 1 if !defined($null);
    undef $self->{content} if ($null);

# finally, chop the output string into lines 

    $output =~ s/(\<[^\n]{30,}?\<\/.+?\>)/$1\n/g;

    print STDOUT "$output\n" if (!defined($list) || $list);

    return $output;
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>  "ejz, group 81",
        version =>             1.0 ,
        date    =>    "30 Apr 2001",
        update  =>    "07 May 2002",
    };
}

###############################################################################

1;
