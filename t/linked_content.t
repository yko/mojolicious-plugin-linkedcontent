use Test::More tests => 12;
use Mojolicious;
use Mojolicious::Controller;

BEGIN {
    use_ok('Mojolicious::Plugin::LinkedContent');
}

my $lc = Mojolicious::Plugin::LinkedContent->new;
isa_ok($lc => 'Mojolicious::Plugin::LinkedContent');

my $app = Mojolicious->new;
$app->log->level('error');
$lc->register($app);

isa_ok($app->renderer->helper->{require_js},  'CODE');
isa_ok($app->renderer->helper->{require_css}, 'CODE');
isa_ok($app->renderer->helper->{include_css}, 'CODE');
isa_ok($app->renderer->helper->{include_js},  'CODE');

my $c = $app->controller_class->new(app => $app);

# Relative path
$app->renderer->helper->{require_js}->($c, 'dummy.js');
my $result = $app->renderer->helper->{include_js}->($c);

is $result, "<script src='/js/dummy.js'></script>\n";

$app->renderer->helper->{require_css}->($c, 'dummy.css');
$result = $app->renderer->helper->{include_css}->($c);

is $result, "<link rel='stylesheet' type='text/css' media='screen' href='/css/dummy.css' />\n";

# Abs path
{
    $c = $app->controller_class->new(app => $app);

    $app->renderer->helper->{require_js}->($c, '/dummy.js');
    $result = $app->renderer->helper->{include_js}->($c);

    is $result, "<script src='/dummy.js'></script>\n";

    $app->renderer->helper->{require_css}->($c, '/dummy.css');
    $result = $app->renderer->helper->{include_css}->($c);

    is $result,
      "<link rel='stylesheet' type='text/css' media='screen' href='/dummy.css' />\n";
};

# Abs url
    $c = $app->controller_class->new(app => $app);

    $app->renderer->helper->{require_js}->($c, 'http://localhost/dummy.js');
    $result = $app->renderer->helper->{include_js}->($c);

    is $result, "<script src='http://localhost/dummy.js'></script>\n";

    $app->renderer->helper->{require_css}->($c, 'http://localhost/dummy.css');
    $result = $app->renderer->helper->{include_css}->($c);

    is $result,
      "<link rel='stylesheet' type='text/css' media='screen' href='http://localhost/dummy.css' />\n";

