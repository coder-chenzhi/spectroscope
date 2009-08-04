#!/usr/bin/perl -w

# $cmuPDL: CalculateSed.pm,v $

##
# @author Raja Sambasivan
#
# Provides an interface for calculating and returning the string-edit distance
# between a set of strings.  This Perl Script assumes that the individual
# elements in each string are seperated by single spaces.  So, each string looks
# like:
#    c1 c2 c2....cn.
##

package Sed;

use strict;
use Test::Harness::Assert;
use List::Util qw(max min);


# Global variables ###############################


# Private routines ##############################

##
# Loads file specified in $self->{INPUT_FILE} into
# a hash and saves this hash in $self->{INPUT_ARRAY}
#
# @param self: The object container
##
my $_load_input_file = sub {

    assert(scalar(@_) == 1);
    my ($self) = @_;

    my %input_array;

    open (my $input_fh, "<$self->{INPUT_FILE}");
    my $i = 0;
    while (<$input_fh>) {
        $i++;
        chomp;
        my $input_array[$i] = $_;
    }

    $self->{INPUT_ARRAY} = \@input_array;
    close($input_fh);
};


##
# Calculates the distance between two strings
#
# @param item1: A reference to an array containing the first string.
# @param item2: A reference to an array containing the second string.
#
# @return: The normalized edit distance between the two items
##
my $_calculate_edit_distance_inner_loop = sub {

    assert(scalar(@_) == 3);
    my($self, $item1_array_ref, $item2_array_ref) = @_;

    my $item1_size = scalar(@{$item1_array_ref});
    my $item2_size = scalar(@{$item2_array_ref});

    return 1 if ($item1_size == 0);
    return 1 if ($item2_size == 0);

    my %mat;

    # Initialize the distance matrix
    for (my $i = 0; $i <= $item1_size; $i++) {        
        $mat{$i}{0} = $i;

        for (my $j = 0; $j <= $item2_size; $j++) {
            $mat{$i}{$j} = 0;
            $mat{0}{$j} = $j;
        }
    }

    for (my $i = 1; $i <= $item1_size; $i++) {
        for (my $j = 1; $j <= $item2_size; $j++) {

            my $cost = ($item1[$i-1] eq $item2[$j-1]) ? 0: 1;
            
            # cell $mat{i}{$j} is the minimum of: 
            #
            # - The cell immediately above plus 1
            # - The cell immediately to the left plus 1
            # - The cell diagonally above and to the left plus the cost
            #
            # Can either insert a new character, delete a character, or
            # substitute an existing character (with associated cost)
            $mat{$i}{$j} = min([$mat{$i-1}{$j} +1,
                                $mat{$i}{$j-1} + 1,
                                $mat{$i-1}{$j-1} + $cost]);
        }
    }

    # Finally, the string-edit distance is the rightmost bottom cell of the matrix
    # Normalize the edit distance by dividing by the larger string
    my $distance = $mat{$item1_size}{$item2_size}./max($item1_size, $item2_size);

    return $distance;
};

                                       
##
# Wrapper function for calculating edit-distance between
# the strings stored in $self->{INPUT_ARRAY}.  Distance between
# strings is stored in $self->{DISTANCE_HASH};
#
# @param self: The object container
##
my $_calculate_edit_distance_internal = sub {
    assert(scalar(@_) == 1);
    my ($self) = @_;

    assert(defined $self->{INPUT_ARRAY});
    my $input_array_ref = $self->{INPUT_ARRAY};
    
    my %distance_hash;
    
    for (my $i = 0; $i < scalar(@{$input_array_ref}); $i++) {        
        $item1 = split(/ /, $input_array_ref->[$i]);

        for (my $j = $i+1; $j < scalar(@{$input_array_ref}); j++) {
            $item2 = split(/ /, $input_array_ref->[$j]);

            my $distance = $self->$_calculate_edit_dist_inner_loop($item1, $item2);
            # Distance array is 1-indexed.
            $distance_hash{$i+1}{$j+1} = $distance;
        }
    }

    $self->{DISTANCE_HASH} = \%distance_hash;
};    


##
# Prints the hash in $self->{DISTANCE_HASH} to $self->{DISTANCE_FILE}.  
# The file is printed in Matlab sparse matrix format.
#
# @param self: The object container
##
my $_print_edit_distance = sub {
    assert(scalar(@_) == 1);
    my ($self) = @_;

    assert(defined $self->{DISTANCE_HASH});
    my $distance_hash_ref = $self->{DISTANCE_HASH};

    for (my $i keys % %{$distance_hash_ref}) {
        %distance_hash_row = $distance_hash_ref->{$i};
        for (my $j keys % %distance_hash_row) {
            print "($i, $j) $distance_hash_row{$j}\n";
        }
    }
};


##
# Loads the data in $self->{DISTANCE_FILE} into a hash
# and stores this hash in $self->{DISTANCE_HASH}
#
# @param self: The object container
##
my $_load_distance_file = sub {
    assert(scalar(@_) == 1);
    my ($self) = @_;

    open(my $distance_fh, "<$self->{DISTANCE_FILE}") or 
        die("Sed.pm: Could not open file containing the distance matrix\n");
    
    my %distance_hash;

    while (<$distance_fh) {
        if(/\((\d+),(\d+)\) ([0-9\.]+)/) {
            my $i = $1;
            my $j = $2;
            my $distance = $3;
            $distance_hash{$i}{$j} = $distance;
        }
    }

    close($distance_fh);
};
    
        
################# Public static functions ###############################

##
# Creates an object for calculating the edit distance between the strings
# specified in the input file.
#
# @param input_file: Each line of the input file is a string.  Individual
# elements of the string must be seperated by spaces.
# @param output_file: The distance between different strings is written to this
# file.  This file is formated in matlab sparse matrix format.
##
sub new {

    assert(scalar(@_) == 3);
    my ($proto, $input_file, $distance_file) = @_;

    my $class = ref($proto) || $proto;
    
    my $self = {};

    $self->{INPUT_FILE} = $input_file;    
    $self->{DISTANCE_FILE} = $distance_file;

    my $self->{DISTANCE_HASH} = undef;
    my $self->{INPUT_ARRAY} = undef;
    
    bless($self, $class);
    return $self;
}


## 
# Returns true if the output file specified in the constructor already exists
##
sub do_output_files_exist {

    assert(scalar(@_) == 1);
    my ($self) = @_;

    if (-e($self->{DISTANCE_FILE})) {
        return 1;
    }

    return 0;
}


##
# Calculates the edit distance between the strings specified in the input file
# and writes the results out to the distance_matrix_file specified in the object
# constructor.
#
# @param input_file: Each line of the input file is a string.  Individual
# elements of the string must be separated by spaces.
# @param output_file: The distance between different strings is written to this
# file.  The output file is formated in matlab sparse matrix format.
# Specifically, it is of the form i, j: <distance>.  Where i corresponds to the
# string at line in the input file and j corresponds to the string at line j in
# the input file.
##
sub calculate_edit_distance {
    
    assert(scalar(@_) == 1);
    my ($self) = @_;

    $self->$_load_input_file();
    $self->$_calculate_edit_distance_internal();
    $self->$_print_edit_distance();
}


##
# Returns the edit distance between two strings.  If the distance
# matrix betwen strings is not yet loaded into memory, this function
# will attempt to load it from the distance_file specified
# in the object constructor.  If this file does not exist, an assert
# will be trigerred.
# 
#
# @param s1_index: The index of the first string in the input file
# @param s2_index: The index of the 2nd string in the input file
#
# @return: The distance between the two strings
#
# Note that the indices are numbered starting at 1.
##
sub get_sed {
 
   assert(scalar(@_) == 3);
    my ($self, $s1_index, $s2_index) = @_;

   # assert that s1_index and s2_index are 1-indexed
   assert($s1_index > 0 && $s_index > 0);

    if(!defined $self->{DISTANCE_HASH}) {
        $self->_$load_distance_file();
    }

    my $retval = (defined $self->{DISTANCE_HASH}->{$s1_index}{$s2_index})?
        $self->{DISTANCE_HASH}->{$s1_index}{$s2_index};

    assert(defined $retval);

    return $retval;
}