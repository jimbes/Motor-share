<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreRideRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'bike_id' => ['nullable', 'integer', 'exists:bikes,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'started_at' => ['required', 'date'],
            'duration_seconds' => ['required', 'integer', 'min:0'],
            'distance_meters' => ['required', 'integer', 'min:0'],
            'avg_speed_kmh' => ['required', 'numeric', 'min:0'],
            'max_speed_kmh' => ['required', 'numeric', 'min:0'],
            'track' => ['required', 'array', 'min:2'],
            'track.*.lat' => ['required', 'numeric', 'between:-90,90'],
            'track.*.lng' => ['required', 'numeric', 'between:-180,180'],
            'track.*.alt' => ['nullable', 'numeric'],
            'track.*.speed' => ['nullable', 'numeric'],
            'track.*.t' => ['nullable', 'string'],
        ];
    }

    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            $bikeId = $this->input('bike_id');

            if ($bikeId && ! $this->user()->bikes()->whereKey($bikeId)->exists()) {
                $validator->errors()->add('bike_id', 'This bike does not belong to you.');
            }
        });
    }
}
