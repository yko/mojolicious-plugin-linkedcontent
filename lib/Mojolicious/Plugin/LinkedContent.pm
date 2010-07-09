# Copyright (C) 2010, Yaroslav Korshak.
 
package Mojolicious::Plugin::LinkedContent;

use warnings;
use strict;
use Carp;

use base 'Mojolicious::Plugin';

our $VERSION = '0.0.1';
my %defaults = (
    'js_base' => '/js',
    'css_base' => '/css',
);

our $reverse = 0;

my $stashkey = '$linked_store';
sub register {
    my ( $self, $app, $params) = @_;
    for (qw/js_base css_base/) {
        $self->{$_} =
          defined($params->{$_}) ? delete($params->{$_}) : $defaults{$_};
    }

    $app->renderer->add_helper(
        require_js => sub {
            $self->store_items('js', @_);
        }
    );
    $app->renderer->add_helper(
        require_css => sub {
            $self->store_items('css', @_);
        }
    );
    $app->renderer->add_helper(
        include_css => sub {
            $self->include_css(@_);
        }
    );
    $app->renderer->add_helper(
        include_js => sub {
            $self->include_js(@_);
        }
    );

    $app->log->debug( "Plugin " . __PACKAGE__ . " registred!" );
}

sub store_items {
    my ($self, $target, $c, @items) = @_;

    my $upd;
    my $store = $c->stash($stashkey) || {}; 
    for ($reverse ? reverse(@items) : @items) {
        if (exists $store->{'garage'}{$target}{$_}) {
            next unless $reverse;
            my $x = $_;
            @{$store->{'box'}{$target}} = grep $_ ne $x, @{$store->{'box'}{$target}};
        }
        $store->{'garage'}{$target}{$_} = 1 ;
        if (!$reverse) { push(@{$store->{'box'}{$target}}, $_) }
        else { unshift(@{$store->{'box'}{$target}}, $_) ; }
     }
    $c->stash($stashkey => $store);
} 

sub include_js {
    my $self = shift;
    my $c = shift;
    local $reverse = 1;
    $self->store_items('js', $c, @_) if @_;
    my $store = $c->stash($stashkey);
    return '' unless $store->{'box'}{'js'};
    my @ct;
    for (@{$store->{'box'}{'js'}}) {
        $c->stash('$linked_item' => $self->{'js_base'} . '/' . $_);

        push @ct,
          $c->render_partial(
            template => 'LinkedContent/js',
            format   => 'html',
            handler  => 'ep',
            template_class => __PACKAGE__
          );
    }
    $c->stash('$linked_item', undef);
    return join '', @ct;
}

sub include_css {
    my $self = shift;
    my $c = shift;
    local $reverse = 1;
    $self->store_items('css', $c, @_) if @_;
    my $store = $c->stash($stashkey);
    return '' unless $store->{'box'}{'css'};
    my @ct;
    for (@{$store->{'box'}{'css'}}) {
        $c->stash('$linked_item' => $self->{'css_base'} . '/' . $_);

        push @ct,
          $c->render_partial(
            template => 'LinkedContent/css',
            format   => 'html',
            handler  => 'ep',
            template_class => __PACKAGE__
          );
    }
    $c->stash('$linked_item', undef);
    return join '', @ct;
}


1;

__DATA__
@@ LinkedContent/js.html.ep
<script src='<%== $self->stash('$linked_item') %>'></script>
@@ LinkedContent/css.html.ep
<link rel='stylesheet' type='text/css' media='screen' href='<%= $self->stash('$linked_item') %>' /> 
__END__

=head1 NAME

Mojolicious::Plugin::LinkedContent - manage linked css and js


=head1 SYNOPSIS

    use base 'Mojolicious';
    sub statup {
        my $self = shift;
        $self->plugin( 'linked_content' );
    }

Somewhere in template:

    % require_js 'myscript.js';
    
And in <HEAD> of your layout: 

    % include_js;


=head1 DESCRIPTION

Helps to manage scripts and styles included in document.

=head1 INTERFACE 

=head1 HELPERS 

=over

=item require_js

Add one or more js files to load queue.

=item require_css

Add one or more css files to load queue.

=item register

Render the plugin.
Internal

=item include_js
=item include_css

Render queue to template

=back

=head2 ITEMS 

=over

=item store_items

Internal method

=back

=head1 CONFIGURATION AND ENVIRONMENT
  
L<Mojolicious::Plugin::LinkedContent> can recieve parameters 
when loaded from  L<Mojolicious> like this:

    $self->plugin(
        'linked_content',
        'js_base'  => '/jsdir',
        'css_base' => '/cssdir'
    );

If no basedirs provided, '/js' and '/css' used by default

=head1 AUTHOR

Yaroslav Korshak  C<< <ykorshak@gmail.com> >>
