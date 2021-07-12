# Copyright (C) 2010, Yaroslav Korshak - 2021 Emiliano Bruni

package Mojolicious::Plugin::LinkedContent;

use warnings;
use strict;
require Mojo::URL;
use Mojolicious::Plugin::Config;
use LWP::Simple;
use File::Temp;

use base 'Mojolicious::Plugin';

our $VERSION = '0.08';

my %defaults = (
    'js_base'  => '/js',
    'css_base' => '/css',
	'reg_config' => 'https://raw.githubusercontent.com/EmilianoBruni/MPLConfig/main/linked_content.cfg',
);

our $reverse = 0;

my $stashkey = '$linked_store';

sub register {
    my ($self, $app, $params) = @_;
    for (qw/js_base css_base reg_config/) {
        $self->{$_} =
          defined($params->{$_}) ? delete($params->{$_}) : $defaults{$_};
    }

	$self->loaded_reg_items($app);

    push @{$app->renderer->classes}, __PACKAGE__;

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
        require_reg => sub {
            $self->store_items_reg(@_);
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

    $app->log->debug("Plugin " . __PACKAGE__ . " registred!");
}

sub loaded_reg_items {
	my $s	= shift;
	my $app	= shift;
	$s->{reg_items} = {};
	return unless ($s->{reg_config});

    my $file = $s->{reg_config};

    my $tmp;
    if ($s->_is_remote($file)) {
        # download
        my $content = get($file);
        $tmp = File::Temp->new(SUFFIX => '.cfg' );
        print $tmp $content;
        $file = $tmp->filename;
        close($tmp);
    }

	my $cfg = $app->plugin('Config' => { file => $file });

	$s->{reg_items} = $cfg->{linkedcontent} if (exists $cfg->{linkedcontent});
	$app->log->debug("Registry library loaded at " . $s->{reg_config});
}

sub store_items_reg {
    my ($s, $c, @items) = @_;
	foreach my $item (@items) {
		if (exists $s->{reg_items}->{$item}) {
			my $item_info = $s->{reg_items}->{$item};
			if (exists $item_info->{deps}) {
				$s->store_items_reg($c,@{$item_info->{deps}});
			}
			foreach (qw/js css/) {
				$s->store_items($_,$c,@{$item_info->{$_}})
					if exists $item_info->{$_};
			}
		}
	}
}

sub store_items {
    my ($self, $target, $c, @items) = @_;

    my $upd;
    my $store = $c->stash($stashkey) || {};
    for ($reverse ? reverse(@items) : @items) {
        if (exists $store->{'garage'}{$target}{$_}) {
            next unless $reverse;
            my $x = $_;
            @{$store->{'box'}{$target}} = grep $_ ne $x,
              @{$store->{'box'}{$target}};
        }
        $store->{'garage'}{$target}{$_} = 1;
        if (!$reverse) { push(@{$store->{'box'}{$target}}, $_) }
        else           { unshift(@{$store->{'box'}{$target}}, $_); }
    }
    $c->stash($stashkey => $store);
}

sub include_js {
    my $self = shift;
    my $c    = shift;
    local $reverse = 1;
    $self->store_items('js', $c, @_) if @_;
    my $store = $c->stash($stashkey);
    return '' unless $store->{'box'}{'js'};
    my @ct;
    for (@{$store->{'box'}{'js'}}) {

		$_ .= '.js' unless (/\.js$/);

        $c->stash('$linked_item' => $self->_prepend_path($_, 'js_base'));

        push @ct, $c->render_to_string(
            template => 'LinkedContent/js',
            format   => 'html',
            handler  => 'ep',

            # template_class is deprecated since Mojolicious 2.62
            # was removed at some point which broke my code.
            # But it'll live here for a while
            template_class => __PACKAGE__
        );
    }
    $c->stash('$linked_item', undef);
    return join '', @ct;
}

sub include_css {
    my $self = shift;
    my $c    = shift;
    local $reverse = 1;
    $self->store_items('css', $c, @_) if @_;
    my $store = $c->stash($stashkey);
    return '' unless $store->{'box'}{'css'};
    my @ct;
    for (@{$store->{'box'}{'css'}}) {

		my $stash = {
            '$linked_media' => 'screen'
        };

        if (ref($_) eq 'HASH') {
            $stash->{'$linked_item'} = $_->{href};
            $stash->{'$linked_media'} = $_->{media} if (exists $_->{media});
        } else {
            $stash->{'$linked_item'} = $_;
        }

        $stash->{'$linked_item'}  .= '.css' unless ($stash->{'$linked_item'} =~/\.css$/);
        $stash->{'$linked_item'} = $self->_prepend_path($stash->{'$linked_item'}, 'css_base');

        $c->stash($stash);

        push @ct, $c->render_to_string(
            template => 'LinkedContent/css',
            format   => 'html',
            handler  => 'ep',

            # template_class is deprecated since Mojolicious 2.62
            # was removed at some point which broke my code.
            # But it'll live here for a while
            template_class => __PACKAGE__
        );
    }
    $c->stash('$linked_item', undef);
    return join '', @ct;
}

sub _prepend_path {
    my ($self, $path, $base) = @_;

    my $url = Mojo::URL->new($path);
    if ($url->is_abs || $url->path->leading_slash) {

        # Absolute path or absolute url returned as is
        return $path;
    }

    # Basepath not defined
    return unless $self->{$base};

    # Prepend path with base
    my $basepath = Mojo::Path->new($self->{$base});
    unshift @{$url->path->parts}, @{$basepath->parts};

    # Inherit leading slash from basepath
    $url->path->leading_slash($basepath->leading_slash);

    return $url->to_string;
}

sub _is_remote  {
    my ($s, $file) = (shift, shift);

    return 1 if ($file =~ /^http/);
}
1;

__DATA__
@@ LinkedContent/js.html.ep
<script src='<%== $self->stash('$linked_item') %>'></script>
@@ LinkedContent/css.html.ep
<link rel='stylesheet' type='text/css' media='<%= $self->stash('$linked_media') %>' href='<%= $self->stash('$linked_item') %>' />
__END__

=encoding utf8


=head1 NAME

Mojolicious::Plugin::LinkedContent - manage linked css and js


=head1 SYNOPSIS

    use base 'Mojolicious';
    sub statup {
        my $self = shift;
        $self->plugin( 'linked_content' );
    }

Somewhere in template:

    % require_css 'mypage.css';
    % require_js 'myscript.js';
    % require_reg 'bootstrap';

And in <HEAD> of your layout:

    %== include_css;
    %== include_js;


=head1 DESCRIPTION

Helps to manage scripts and styles included in document.

=head1 INTERFACE

=head1 HELPERS

=over

=item require_js

Add one or more js files to load queue.

=item require_css

Add one or more css files to load queue.

=item require_reg

Add a library and its dependences based on reg_config file

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
        'reg_config' => '/linked_content.cfg',
    );

If no basedirs provided, '/js' and '/css' used by default.
If no reg_config is provided a cloud example file is used.
Default reg_config URL: https://raw.githubusercontent.com/EmilianoBruni/MPLConfig/main/linked_content.cfg

=head1 AUTHOR

Yaroslav Korshak  C<< <ykorshak@gmail.com> >>,
Emiliano Bruni C<< <info@ebruni.it >>

=head1 CREDITS

=over 2

Oliver Günther

=back

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 - 2013, Yaroslav Korshak
Copyright (C) 2019 - 2021, Emiliano Bruni

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
