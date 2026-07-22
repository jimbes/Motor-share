<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RideResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'started_at' => $this->started_at,
            'duration_seconds' => $this->duration_seconds,
            'distance_meters' => $this->distance_meters,
            'avg_speed_kmh' => $this->avg_speed_kmh,
            'max_speed_kmh' => $this->max_speed_kmh,
            'polyline' => $this->polyline_simplified,
            'user' => [
                'id' => $this->user->id,
                'name' => $this->user->name,
            ],
            'bike' => $this->whenLoaded('bike', fn () => $this->bike ? [
                'id' => $this->bike->id,
                'brand' => $this->bike->brand,
                'model' => $this->bike->model,
                'nickname' => $this->bike->nickname,
            ] : null),
            'photos' => $this->whenLoaded('photos', fn () => $this->photos->map(fn ($photo) => [
                'id' => $photo->id,
                'url' => $photo->url,
            ])),
            'likes_count' => (int) ($this->likes_count ?? 0),
            'comments_count' => (int) ($this->comments_count ?? 0),
            'liked_by_me' => (bool) ($this->liked_by_me ?? false),
        ];
    }
}
