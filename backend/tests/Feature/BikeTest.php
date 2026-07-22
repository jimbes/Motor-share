<?php

namespace Tests\Feature;

use App\Models\Bike;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BikeTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_create_a_bike(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->postJson('/api/bikes', [
            'brand' => 'Ducati',
            'model' => 'Monster 937',
            'year' => 2023,
            'nickname' => 'Red Beast',
            'engine_cc' => 937,
        ]);

        $response->assertCreated()->assertJsonFragment(['brand' => 'Ducati', 'nickname' => 'Red Beast']);
        $this->assertDatabaseHas('bikes', ['user_id' => $user->id, 'brand' => 'Ducati']);
    }

    public function test_a_user_only_sees_their_own_bikes(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();

        Bike::factory()->for($user)->create(['brand' => 'Yamaha']);
        Bike::factory()->for($other)->create(['brand' => 'Honda']);

        $response = $this->actingAs($user)->getJson('/api/bikes');

        $response->assertOk()->assertJsonCount(1);
        $response->assertJsonFragment(['brand' => 'Yamaha']);
        $response->assertJsonMissing(['brand' => 'Honda']);
    }

    public function test_a_user_can_update_their_own_bike(): void
    {
        $user = User::factory()->create();
        $bike = Bike::factory()->for($user)->create(['nickname' => 'Old Name']);

        $response = $this->actingAs($user)->putJson("/api/bikes/{$bike->id}", [
            'nickname' => 'New Name',
        ]);

        $response->assertOk()->assertJsonFragment(['nickname' => 'New Name']);
    }

    public function test_a_user_cannot_update_another_users_bike(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $bike = Bike::factory()->for($other)->create();

        $response = $this->actingAs($user)->putJson("/api/bikes/{$bike->id}", [
            'nickname' => 'Hijacked',
        ]);

        $response->assertNotFound();
    }

    public function test_a_user_can_delete_their_own_bike(): void
    {
        $user = User::factory()->create();
        $bike = Bike::factory()->for($user)->create();

        $response = $this->actingAs($user)->deleteJson("/api/bikes/{$bike->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('bikes', ['id' => $bike->id]);
    }

    public function test_a_user_cannot_delete_another_users_bike(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $bike = Bike::factory()->for($other)->create();

        $response = $this->actingAs($user)->deleteJson("/api/bikes/{$bike->id}");

        $response->assertNotFound();
        $this->assertDatabaseHas('bikes', ['id' => $bike->id]);
    }
}
