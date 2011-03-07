#!/usr/local/bin/perl -w
require Mail::Send;

my $user = "kt6";
my $message = "This is a test email to investigate the broken PERL Help Desk ticket creation in RT 205601";
my $instance = "pathogen";
my $organism = "Tyrannosaurus rex";

&sendMessage($user, $message, $instance, $organism);

sub sendMessage {
   my ($user,$message,$instance, $organism) = @_;
 
   my $to = "";
 
   if ($instance eq 'test') {
       $to = $user;
    }
    else {
      $to = 'arcturus-help@sanger.ac.uk';
      $cc = $user if defined($user);
    }
 
    print STDOUT "Sending message to $to\n";
 
    my $mail = new Mail::Send;
     $mail->to($to);
     $mail->cc($cc);
     $mail->subject("Unexpected change in the number of free reads for $organism");
     $mail->add("X-Arcturus", "contig-transfer-manager");
     my $handle = $mail->open;
     print $handle "$message\n";
     $handle->close or die "Problems sending mail to $to cc to $cc: $!\n";
 
 }

