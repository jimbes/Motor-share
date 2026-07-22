<?php

namespace Tests\Feature;

use App\Models\Bike;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RideTest extends TestCase
{
    use RefreshDatabase;

    private function samplePayload(array $overrides = []): array
    {
        $track = [];
        for ($i = 0; $i < 10; $i++) {
            $track[] = [
                'lat' => 43.5 + $i * 0.001,
                'lng' => 5.4 + $i * 0.001,
                'alt' => 100.0,
                'speed' => 60.0,
                't' => now()->addSeconds($i * 5)->toIso8601String(),
            ];
        }

        return array_merge([
            'title' => 'Sunday Mountain Loop',
            'description' => 'Great twisties.',
            'started_at' => now()->subHour()->toIso8601String(),
            'duration_seconds' => 3600,
            'distance_meters' => 45000,
            'avg_speed_kmh' => 55.5,
            'max_speed_kmh' => 120.0,
            'track' => $track,
        ], $overrides);
    }

    public function test_a_user_can_upload_a_ride(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->postJson('/api/rides', $this->samplePayload());

        $response->assertCreated()->assertJsonFragment(['title' => 'Sunday Mountain Loop']);
        $this->assertDatabaseHas('rides', ['user_id' => $user->id, 'title' => 'Sunday Mountain Loop']);
    }

    public function test_a_ride_upload_stores_a_simplified_polyline(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/rides', $this->samplePayload());

        $ride = Ride::first();
        $this->assertNotNull($ride->polyline_simplified);
        $this->assertLessThanOrEqual(count($ride->track), count($ride->polyline_simplified));
    }

    public function test_a_ride_can_be_linked_to_the_users_own_bike(): void
    {
        $user = User::factory()->create();
        $bike = Bike::factory()->for($user)->create();

        $response = $this->actingAs($user)->postJson('/api/rides', $this->samplePayload(['bike_id' => $bike->id]));

        $response->assertCreated();
        $this->assertDatabaseHas('rides', ['bike_id' => $bike->id]);
    }

    public function test_a_ride_cannot_be_linked_to_another_users_bike(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $bike = Bike::factory()->for($other)->create();

        $response = $this->actingAs($user)->postJson('/api/rides', $this->samplePayload(['bike_id' => $bike->id]));

        $response->assertUnprocessable()->assertJsonValidationErrors('bike_id');
    }

    public function test_ride_upload_requires_at_least_two_track_points(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->postJson('/api/rides', $this->samplePayload(['track' => [['lat' => 1, 'lng' => 1]]]));

        $response->assertUnprocessable()->assertJsonValidationErrors('track');
    }

    public function test_the_feed_lists_rides_newest_first(): void
    {
        $user = User::factory()->create();
        $older = Ride::factory()->for($user)->create(['started_at' => now()->subDays(2)]);
        $newer = Ride::factory()->for($user)->create(['started_at' => now()->subDay()]);

        $response = $this->actingAs($user)->getJson('/api/rides');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertEquals([$newer->id, $older->id], $ids->toArray());
    }

    public function test_the_feed_omits_the_full_track_but_includes_a_polyline(): void
    {
        $user = User::factory()->create();
        Ride::factory()->for($user)->create();

        $response = $this->actingAs($user)->getJson('/api/rides');

        $response->assertOk();
        $response->assertJsonMissingPath('data.0.track');
        $this->assertNotNull($response->json('data.0.polyline'));
    }

    public function test_a_ride_detail_includes_the_full_track(): void
    {
        $user = User::factory()->create();
        $ride = Ride::factory()->for($user)->create();

        $response = $this->actingAs($user)->getJson("/api/rides/{$ride->id}");

        $response->assertOk();
        $this->assertNotEmpty($response->json('track'));
    }

    public function test_my_stats_only_aggregates_the_authenticated_users_rides(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();

        Ride::factory()->for($user)->create(['distance_meters' => 10000, 'started_at' => now()->subDays(2)]);
        Ride::factory()->for($user)->create(['distance_meters' => 20000, 'started_at' => now()->subDays(20)]);
        Ride::factory()->for($other)->create(['distance_meters' => 99000, 'started_at' => now()->subDay()]);

        $response = $this->actingAs($user)->getJson('/api/me/stats');

        $response->assertOk()->assertJson([
            'rides_count' => 2,
            'distance_meters' => 30000,
            'week_rides_count' => 1,
            'week_distance_meters' => 10000,
        ]);
    }
}
