package NewHTML;

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

sub submitbuttonbar {
# add submit button and: a reset button or a return link below or nothing
    my $self  = shift;
    my $reset = shift;
    my $line  = shift;
    my $jump  = shift;
    my $text  = shift;

    my $buttonbar = "<TABLE><TR>";
    $buttonbar .= "<TD ALIGN=CENTER WIDTH=50%><INPUT name='submit' type=";
    $buttonbar .= "'submit' value='&nbsp Submit &nbsp'></TD>";
    if (defined($reset) && $reset eq '1') {
        $buttonbar .= "<TD WIDTH=50%><INPUT name='reset'  type='reset'></TD>";
    } elsif (defined($reset) && $reset =~ /\w/ && $reset =~ /\D/) {
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
    $colour = "orange" if (!$colour);
    $error .= "<TABLE ALIGN=CENTER><TR><TD BGCOLOR=\"$colour\" WRAP><H3>";
    $error .= $text if ($text);
    $error .= "unspecified error" if (!$text);
    $error .= "</H3></TD></TR></TABLE><HR>";
    if ($link) {
        $ltxt = "GO BACK" if (!$ltxt);
        $error .= "<TABLE ALIGN=CENTER><TR>";
        $error .= "<TD WIDTH=200 ALIGN=CENTER><A href=\"$link\">$ltxt</A></TD>";
        $error .= "</TR></TABLE>";
    }
 
    $$content[$part] .= $error;
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
    my $text  = shift;
    my $part  = shift;
    my $hline = shift;

    $part = $self->{current} if (!defined($part) || $part <= 0);
    my $content = $self->{content}; #  partition contents

    $text =~ s/banner/$self->{banner}/ if ($text && $self->{banner});

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

    my $password = 'PASSWORD'; # used if not replaced below
    my $query = "<TABLE ALIGN=CENTER border=0 cellpadding=2><TR>";
    if (defined($id) && $id) {
        $query .= "<TH ALIGN=RIGHT NOWRAP>User ID</TH><TD ALIGN=LEFT NOWRAP>";
        $query .= "<INPUT NAME='identify' SIZE=$size VALUE=''></TD><TD>&nbsp</TD>";
        $password = 'password'; # default for "identify, password, [pwrepeat]"
    }
    $query .= "<TH ALIGN=RIGHT NOWRAP>Password</TH><TD ALIGN=LEFT NOWRAP>";
    $query .= "<INPUT TYPE=PASSWORD NAME='$password' SIZE=$size VALUE=''></TD>";
    if (defined($rp) && $rp) {
        $query .= "<TD>&nbsp</TD><TH ALIGN=RIGHT NOWRAP>Type again</TH>";
        $query .= "<TD ALIGN=LEFT NOWRAP>";
        $query .= "<INPUT TYPE=PASSWORD NAME='pwrepeat' SIZE=$size VALUE=''></TD>";
    }
    $query .= "</TR></TABLE>";

    add($self,$query,0,$line);
}

###############################################################################

sub ingestCGI {
# transfer CGI input values as hidden values to current page (see MyCGI.pm)
    my $self  = shift;

    my $in = $self->{cgi_input};
    return if (ref($in) ne 'HASH');

    foreach my $key (keys (%$in)) {
        hidden($self,$key,$in->{$key}) if ($key !~ /submit|confirm/i);
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
    } else {
        $input{$name} = $value;
# print "single value $name preload<br>";
    }

# scan the page for <INPUT tags with undefined values for the input parameters

    foreach my $name (keys (%input)) {

        if ($content->[$part] =~ /\<\s*(input\s[^\<\>]*?name\s*\=\s*[\'\"]?$name[\'\"]?[^\<\>]*)\>/is) {
            my $original = $1; my $replacement = $1;
            if ($replacement =~ /radio|checkbox/i) {
        # check the button  
                $replacement .= ' checked' if ($replacement !~ /checked/);
            }
        # if the tag does not have a value field, add it
            elsif (!($replacement =~ /value/i)) {
                $replacement .= " VALUE='$input{$name}'";
            }
            else {
        # fill the space after the value field with the preload value
                my $pattern = '[\'\"]\s*[\'\"]|[\'\"]?([^\'\"]+)[\'\"]?';
                $pattern =~ s/\'/\\'/g; # '
                $replacement =~ s/value\s*\=\s*($pattern)/VALUE='$input{$name}' /i;
                my $valuefield = $1;
                $valuefield =~ s/[\'\"]//g; # remove quotes, if any
# print "the replacement: $replacement<br>"; # if ($list);
                $replacement = $original if ($valuefield && !$over);
            }
        # now substitute the original string by the new one with values
            $content->[$part] =~ s/$original/$replacement/ if ($replacement ne $original);;
        }
# else {
#    print "NO match <br>\n" if ($list);
#}
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
    my $list = shift; # reference to array with names
    my $size = shift; # optional width of field
    my $line = shift; # continuation line

# compose HTML select construct

    my $width = ''; # default no width specification
    $width = "width=$size" if ($size && $size > 0);

    my $select = "SELECTED";
    my $choice = "<SELECT $width name = \'$name\'>";
    foreach my $listitem (@$list) {
       $choice .= "<OPTION value = \'$listitem\' $select>$listitem";
       $select = '';
    }
    $choice .= "</SELECT>";

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
            $output = $counter if ($part =~ /$tracer/);
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
    $layout .= "<TD ROWSPAN=3>CON0</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON3</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON4</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON5</TD>";
    $layout .= "</TR><TR>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON6</TD>";
    $layout .= "<TD WIDTH=$side BGCOLOR=$bgcolor VALIGN=TOP>CON7</TD>";
    $layout .= "</TR></TABLE>";

    $self->{layout} = $layout;
}

###############################################################################

sub frameborder {
# put the partition 0 inside a 
    my $self = shift;
    my $mtop = shift;
    my $side = shift;
    my $bgcolor = shift;
    my $mbot = shift;

    $mtop = 5   if (!defined($mtop));
    $side = 25  if (!$side);
    $bgcolor = "beige" if (!$bgcolor);
    $mbot = $mtop      if (!defined($mbot));

    undef my $layout;
    $layout .= "<TABLE ALIGN=CENTER WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0>";
    $layout .= "<TR><TD COLSPAN=3 HEIGHT=$mtop BGCOLOR=$bgcolor>CON1</TD></TR>";
    $layout .= "<TR><TD WIDTH=$side\% BGCOLOR=$bgcolor>CON2</TD>";
    $layout .= "<TD>CON0</TD>";
    $layout .= "<TD WIDTH=$side\%  BGCOLOR=$bgcolor>CON3</TD></TR>";
    $layout .= "<TR><TD COLSPAN=3 HEIGHT=$mbot BGCOLOR=$bgcolor>CON4</TD></TR>";
    $layout .= "</TABLE>";

    $self->{layout} = $layout;
}

###############################################################################

sub quartetborder {
# put 4 partitions (nr 0,4,5,6) at the centre of a frameborder layout
    my $self = shift;

    &frameborder($self,@_);
    my $quartet = "<CENTER><TABLE CELLPADDING=5 WIDTH=100%><TR>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON0</TD>";
    $quartet   .= "<TD WIDTH=50% VALIGN=TOP NOWRAP>CON5</TD>";
    $quartet   .= "</TR><TR>";
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
    my $lout = shift; # 0 for nocenter; 1 for center; 2 for no center & line; 3 for center & line

    my $address;
    $address .= "<center>"  if ($lout == 1 || $lout == 3);
    $address .= "</center>" if ($lout == 0 || $lout == 2);
    $address .= "<hr>" if ($lout >= 2);

    $address .= "<address>Please send suggestions or problem reports ";
    $address .= "to <a href=\"mailto:$mail\">$name</a></address>";

    $self->{address} = $address;
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
        foreach (my $i=0 ; $i < 9 ; $i++) {
# test if the contents element contains any text
	    my $fill = 0;
            $fill = 1 if ($content->[$i] && $content->[$i] =~ /\>[^\<\>\s]+\<|[^\<\>\s]+/);
# print "part $i  $content->[$i]  fill <br>";
            $layout =~ s/CON$i/$content->[$i]/ if ($content->[$i] && $content->[$i] =~ /\>[^\<\>\s]+\<|[^\<\>\s]+/);
            $layout =~ s/CON$i/$blank/g       if (!$content->[$i] || $content->[$i] !~ /\>[^\<\>\s]+\<|[^\<\>\s]+/);
        }
        $output .= $layout;
    } else {
        $output .= $content->[0];
    }
    $output .= $address if (defined($address));
    $output .= "</BODY></HTML>";

# substitute values for standard place holders

#    $output =~ s/SANGERLOGO/<IMG SRC="sanger.gif">/;
#    $output =~ s/ARCTURUSLOGO/<IMG SRC="arcturus.jpg">/;

# clear the contents

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








