package MyGA;

#############################################################################
#
# Genetic Algorithm implementation
#
#############################################################################

use strict;
use vars qw($VERSION);

$VERSION = 1.0;

###############################################################################
# constructor new: create a handle to a new 
###############################################################################

sub new {
# create an instance read object 
    my $prototype = shift;
    my $fitness   = shift; # reference to fitness subroutine (\&sub)
    my $symbols   = shift; # reference to array with allowed tokens

    my $class = ref($prototype) || $prototype;

    my $self  = {};
    
    $self->{population} = [];    # array of pointers to population vectors
    $self->{merit}      = {};    # hash with merit values keyed on pointer values

    $self->{symbols} = $symbols; # the reference to array with valid tokens  
    $self->{fitness} = $fitness; # reference to the merit function

    $self->{generation} = 0;     # generation counter

    $self->{control} = {};       # hash for control parameters

# set default values

    $self->control('mutation',0.05); # starting value for mutation rate per vector
    $self->control('mdynamic',0);    # default no dynamic rate change (rate fixed)
    $self->control('ordering',0);    # default random initial vectors
    $self->control('ranking' ,1);    # default merit ranking used; value is bias
    $self->control('popsize' ,0);    # default population size
    $self->control('vlength' ,0);    # default vector length
    $self->control('elitism' ,1);    # default use elitism (keep best)
    $self->control('dynamism',0);    # default use static population size

    bless ($self, $class);
    return $self;
}

###############################################################################

sub control {
# define control parameters 
    my $self = shift;
    my $item = shift; # the control item 
    my $ival = shift; # its (new) value

    $ival = 0 if !defined($ival);

    $self->{control}->{$item} = $ival if defined($item);
}

###############################################################################

sub initialize {
# initialize a new population
    my $self = shift;
    my $size = shift; # population size (overrides default)
    my $vlgt = shift; # vector length   (overrides default)

# if no size or length specified, try control parameters;

    $size = $self->{control}->{popsize} if !$size;
    $size = 0 if !defined($size);
    die "initialize FAILED: invalid pupulation size ($size) specified" if (!$size || $size < 0);
    $self->{control}->{popsize} = $size if !$self->{control}->{popsize}; # adopt as new default

    $vlgt = $self->{control}->{vlength} if !$vlgt;
    $vlgt = 0 if !defined($vlgt);
    die "initialize FAILED: invalid vector length ($vlgt) specified" if (!$vlgt || $vlgt <= 0);
    $self->{control}->{vlength} = $vlgt if !$self->{control}->{vlength}; # adopt as new default
    
    my $count = 0;
    for (my $i = 0 ; $i < $size ; $i++) {
# generate a new random  vector
        undef my @vector;
        if (&rvector(0,$self,\@vector,$vlgt)) { 
            $self->{population}->[$i] = \@vector; # add pointer to array
            $count++;
	}
        else {
            $self->{population}->[$i] = 'invalid'; # signal failed vector
	}
    }

    $self->{generation} = 0;

# get the merits of the population vectors and sort according to merit

    $self->evaluate();
    $self->sort();

    return $count; # number of vectors successfully initialized
}

###############################################################################

sub rvector {
# generate a trial vector from the allowed tokens (private function)
    my $lock   = shift;
    my $self   = shift;
    my $vector = shift; # reference to an array for output
    my $length = shift; # its length

    die "! Y're not supposed to use private method 'rvector'\n" if ($lock);

# random vectors, ordered, inverse ordered numerical or character
# develop further

    undef @$vector;
    while ($length-->0) {
        push @$vector, &rsymbol(0,$self);
    }    

}

###############################################################################

sub rsymbol {
# generate a trial vector from the allowed tokens (private function)
    my $lock    = shift;
    my $self    = shift;
    my $symbols = shift; # array ref with symbols (overrides default)

    die "! Y're not supposed to use private method 'rsymbol'\n" if ($lock);

    my $symbol; # output

    my $symbols = $self->{symbols} if !$symbols; # reference to array of symbols

# if the symbols are presented as array, draw a random symbol

    my $ref = ref($symbols);

    if ($ref =~ /ARRAY/) {
        my $random = int(&random(scalar(@$symbols))); # random array index
        $symbol = $symbols->[$random];
    }
# if symbols is a hash, draw a random number between {lower} and {upper}
##    elsif ($ref =~ /HASH/) {
#        my $range  = $symbols->{upper} - $symbols->{lower};
#        $symbol = $symbols->{lower} + rand $range;
#    }
}

###############################################################################

sub random {
# return random number in range min-max or 0-min
    my ($min,$max) = @_;

    my $range = $min;
    if (defined($max)) {
        $range = $max - $range;
    }
    else {
        $min = 0;
    }

    return $min + rand $range;
}

###############################################################################

sub wrandom {
# return a weighted random index
    my $lock    = shift; # private function
    my $weights = shift; # reference to accumulated weights array

    die "! Y're not supposed to use private method 'wrandom'\n" if ($lock);

    my $length = scalar(@$weights);
    $length-- if (!$weights->[$length-1]); # protect against last one == 0
    my $wrange = $weights->[$length-1]; # last element

    my $random = &random(0,$wrange);

    my $i = 0;
# this loop returns the index of the first weight above the threshold
    while ($i+1 < $length && $weights->[$i] < $random) {
        $i++;
    }

    return $i;
}

###############################################################################

sub evaluate {
# determine the merit all individual vectors in the population
    my $self = shift;

    my $fitness = $self->{fitness};

    my $count = 0;
    foreach my $reference (@{$self->{population}}) {
        if ($reference =~ /ARRAY/) {
            $self->{merit}->{$reference} = &$fitness($reference);
            $count++;
        }
        else {
            $self->{merit}->{$reference} = 0; # no merit whatsoever
        }
    }

# should also determine convergence etc...

    return $count; # number of vectors evaluated
}

###############################################################################

sub sort {
# inverse sort the population according to merit (highest merit first)
    my $self = shift;

    my $population = $self->{population};
    my $merit      = $self->{merit};

    @$population = sort {-$merit->{$a} <=> -$merit->{$b}}  @$population;
}

###############################################################################

sub offspring {
# breed the next generation
    my $self = shift;
    my $rate = shift; # mutation rate overrides default value

    my $parents  = $self->{population}; # array reference
    my $popsize  = scalar(@$parents); # size of parent population

    my @children = []; # temporary space for offspring population

# determine size of offspring population (could be done dynamically)

    my $offsize = $popsize;
    if ($self->{control}->{dynamism}) {
   # to be completed
    }

# determine mutation rate (could be done dynamically, using convergence info)

    my $mutation = $rate || $self->{control}->{mutation};
    if (!defined($rate)  && $self->{control}->{mdynamic}) {
   # to be completed
    }

# possibly prime the next generation with one or more best parents

    my $elite = $self->{control}->{elitism};
    while ($elite-- > 0) {
         push @children, $parents->[$elite];
         $offsize--;
    }

# prepare the probability vector for random draws

    my @weights;
    my $ranking = $self->{control}->{ranking};  
    for (my $i = 0 ; $i < $popsize ; $i++) {
        if ($ranking > 0) {
            $weights[$i] = ($popsize-$i-1) + $ranking; 
        }
        else {
            my $reference = $parents->[$i];
            $weights[$i] = $self->{merit}->{$reference};
        }
    # now get the accumulated merit (the last one will have the total weight)
        $weights[$i] += $weights[$i-1] if $i;
    }

# for each child do: select a parent & a mutation OR two parents and crossover

    while ($offsize-- > 0) {
    # choose a parent
        my $mother = &wrandom(0, \@weights); # draw a weighted random number
        my @vector = @{$parents->[$mother]}; # copy vector
        if (&random(1.0) < $mutation) {
    # do a mutation (details in sub)
            &mutate(0,$self,\@vector);       # apply a mutation
            push @children,\@vector;         # add to offspring
        }
        else {
    # do a cross-over: select another parent
            my $stored = $weights[$mother];
            $weights[$mother] = 0; # prevents mother being selected again
            my $father = &wrandom(0,\@weights);
            $weights[$mother] = $stored; # restore
            my @sister =  @{$parents->[$father]};
            &crossover(0,$self,\@vector,\@sister); # new in both vector and sister
            push @children,\@vector;                 # add to offspring
            push @children,\@sister if ($offsize && --$offsize);
        }
    }

# replace parents by offspring
    
    $self->{population} = \@children;
    $self->{generation}++;
}

###############################################################################

sub mutate {
# (private function) replace a random allelle
    my $lock   = shift;
    my $self   = shift;
    my $vector = shift; # reference to array

    die "! Y're not supposed to use private method 'mutate'\n" if ($lock);

# current form simplest possibility

    my $random = int(&random(scalar(@$vector))); # index of element to replace 
    $vector->[$random] = &rsymbol(0,$self);
}

###############################################################################

sub crossover {
# (private function) 
    my $lock   = shift;
    my $self   = shift;
    my $vector = shift;
    my $sister = shift;

    die "! Y're not supposed to use private method 'crossover'\n" if ($lock);

    my $length = scalar(@$vector);
    die "! Incompatible vectors in crossover" if (scalar(@$sister) != $length);

    my $method = 0;

# method: 0 for random switch between vectors
#         1 for single point crossover
#         2 for two point crossover

    if ($method == 0) {
        for (my $i = 0 ; $i < $length ; $i++) {
            if (&random(1.0) >= 0.5) {
                my $swap = $vector->[$i];
                $vector->[$i] = $sister->[$i];
                $sister->[$i] = $swap;
            }
        }        
    }

}

###############################################################################

sub listing {
}

###############################################################################

1;










