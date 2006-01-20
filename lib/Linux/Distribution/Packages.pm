package Linux::Distribution::Packages;

use 5.006000;
use strict;
use warnings;

use base qw(Linux::Distribution);

our $VERSION = '0.01';

my %commands = (
    'debian'                => 'dpkg',
    'ubuntu'                => 'dpkg',
    'redhat'                => 'rpm',
    'suse'                  => 'rpm',
    'gentoo'                => 'equery',
);

our @EXPORT_OK = qw(distribution_packages distribution_write format);

sub new {
    my $package = shift;
   
    my $self = {
        'command'           => '',
        'format'            => 'native',
        '_data'             => '',
        'options'           => ''
    };

    bless $self, $package;
    $self->SUPER::new();
    $self->distribution_name();
    $self->distribution_packages();
    return $self;
}

sub distribution_packages {
    my $self = shift || new();
    if ($commands{$self->{'DISTRIB_ID'}}){
        bless $self, 'Linux::Distribution::Packages::' . $commands{$self->{'DISTRIB_ID'}};
    } else {
        print "Distribution [ $self->{'DISTRIB_ID'} ] not supported\n";
        exit;
    }
    $self->_retrieve_all();
}

sub distribution_write {
    my $self = shift;
    my $print_function = '_list_' . $self->{'format'};
    $self->$print_function();
}

sub format {
    my $self = shift;
    $self->{'format'} = shift || 'native';
}

sub option {
    my $self = shift;
    $self->{'options'} = shift;
}

sub _retrieve_all {
    my $self = shift;
    $self->{'command'} = $self->_command();
    $self->{'_data'} = ` $self->{'command'} `;
    die "Error $? running \'$self->{'command'}\'\n" if $?;
}

sub _list_native {
    my $self = shift;
    print $self->{_data};
}

sub _list_xml {
    use XML::Writer;
    my $self = shift;
    my $writer;
    if ($self->{'format'} =~ m/xml/i){
        $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 2);
        $writer->startTag('distribution', "name" => $self->{'DISTRIB_ID'}, "release" => $self->distribution_version());
    }
    my $hash = $self->_parse($writer);
    $writer->endTag('distribution');
}

sub _list_csv {
    my $self = shift;
    $self->_parse();
}

sub _row_csv {
    my $self = shift;
    print "\'" . join("\',\'", @_) . "\'\n";
}

sub _parse {
    my $self = shift;
    my $row_func='_row_' . $self->{'format'};
    my @data = split '\n', $self->{'_data'};
    foreach my $row (@data){
        $self->$row_func($row);
    }
}

return 1;

package Linux::Distribution::Packages::equery;
use base qw(Linux::Distribution::Packages);

sub _command {
    my $self = shift;
    my $command = 'equery list';
    if ($self->{'options'}){ $command .= ' ' . $self->{'options'}; }
    return $command;
}

sub _parse {
    my $self = shift;
    my @data = split '\n', $self->{_data};
    my $writer=shift;
    foreach my $row (@data){
        my ($dir, $pkg, $ver);
        next if $row =~ m/.*installed packages.*/;
        if ($row =~ m/\-(r\d+)$/){ 
            ($dir, $pkg, $ver) = $row =~ m/(.+)\/(.+)\-(.+(\-(r\d+)))$/;
        } else {
            ($dir, $pkg, $ver) = $row =~ m/(.+)\/(.+)\-(.+)/;
        }
        if ($self->{'format'} =~ m/xml/i){ $writer->emptyTag('package', 'name' => $pkg, 'version' => $ver , 'category' => $dir); next; }
        my $row_func='_row_' . $self->{'format'};
        $self->$row_func($dir, $pkg, $ver, '');
    }
}

return 1;

package Linux::Distribution::Packages::dpkg;
use base qw(Linux::Distribution::Packages);

sub _command {
    my $command = 'dpkg --list';
    my $self = shift;
    if ($self->{'options'}){ $command .= ' ' . $self->{'options'}; }
    return $command;
}

sub _parse {
    my $self = shift;
    my @data = split '\n', $self->{_data};
    my $writer=shift;
    foreach my $row (@data){
        my ($ii, $desc, $pkg, $ver);
        next if $row =~ m/^(Desired|\||\+).*/;
        ($ii, $pkg, $ver, $desc) = $row =~ m/^(.+?)\s+(.+?)\s+(.+?)\s+(.+)$/;
        if ($self->{'format'} =~ m/xml/i){ $writer->emptyTag('package', 'name' => $pkg, 'version' => $ver , 'description' => $desc); next; }
        my $row_func='_row_' . $self->{'format'};
        $self->$row_func('', $pkg, $ver, $desc);
    }
}

return 1;


package Linux::Distribution::Packages::rpm;
use base qw(Linux::Distribution::Packages);

sub _command {
    my $command = 'rpm -qa';
    my $self = shift;
    if ($self->{'options'}){ $command .= ' ' . $self->{'options'}; }
    return $command;
}

sub _parse {
    my $self = shift;
    my @data = split '\n', $self->{_data};
    my $writer=shift;
    foreach my $row (@data){
        my ($pkg, $ver);
        next if $row =~ m/^(Desired|\||\+).*/;
        ($pkg, $ver) = $row =~ m/^(.+)\-+(.+\-.+)$/;
        if ($self->{'format'} =~ m/xml/i){ $writer->emptyTag('package', 'name' => $pkg, 'version' => $ver ); next; }
        my $row_func='_row_' . $self->{'format'};
        $self->$row_func('', $pkg, $ver, '');
    }
}

return 1;
__END__


=head1 NAME

Linux::Distribution::Packages - list all packages on various Linux distributions 

=head1 SYNOPSIS

  use Linux::Distribution::Packages qw(distribution_packages distribution_write format option);

  $linux = new Linux::Distribution::Packages;
  $linux->format( 'xml' );
  $linux->distribution_write();

  # If you want to reload the package data
  $linux->distribution_packages();

=head1 DESCRIPTION

This is a simple module that uses Linux::Distribution to guess the linux 
distribution and then uses the correct commands to list all the packages 
on the system and then output them in one of three formats:  native, csv, 
and xml. 

The module inherits from Linux::Distribution, so can also use its calls.

=head2 EXPORT

None by default.

=head1 TODO

* Add the capability to correctly get packages for all recognized distributions.
* Make 'distribution_write' write to a file you set.
* Seperate out parsing from writing.  Parse data to hash and give access to hash. 
Then write the formatted data from the hash.

=head1 AUTHORS

Judith Lebzelter, E<lt>judith@osdl.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut

