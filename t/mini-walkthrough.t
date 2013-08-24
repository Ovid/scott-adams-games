use Test::Most;
use lib 't/lib';
use TestAdventure 't/data/adv00';

#
# This walkthrough will let you pass the mini-adventure using ScottAdams.c, so
# it should be a reasonable test of bin/scott.pl. Currently you cannot pass
# the adventure with this.
#
# See t/gameplay.t for better examples
#

my $response = doit("Go East");
ok $response;
$response = doit("Go East");
$response = doit("Get Axe");
$response = doit("Go North");
$response = doit("Get Ox");
$response = doit("Say Bunyon");
$response = doit("Swim");
$response = doit("Go South");
$response = doit("Go West");
$response = doit("Take mud");
$response = doit("Go West");
$response = doit("Get Axe");
$response = doit("Get Ox");
$response = doit("Get Fruit");
$response = doit("Go East");
$response = doit("Take mud");
$response = doit("Chop Tree");
$response = doit("Drop Axe");
$response = doit("Get Mud");
$response = doit("Go Stump");
$response = doit("Drop Mud");
$response = doit("Drop Ox");
$response = doit("Drop Fruit");
$response = doit("Go Down");
$response = doit("Get Rubies");
$response = doit("Go Up");
$response = doit("Drop Rubies");
$response = doit("Score");

done_testing;

