<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreBikeRequest;
use App\Http\Resources\BikeResource;
use Illuminate\Http\Request;

class BikeController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        return BikeResource::collection(
            $request->user()->bikes()->latest()->get()
        );
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreBikeRequest $request)
    {
        $bike = $request->user()->bikes()->create($request->validated());

        return new BikeResource($bike);
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, string $id)
    {
        $bike = $request->user()->bikes()->findOrFail($id);

        return new BikeResource($bike);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(StoreBikeRequest $request, string $id)
    {
        $bike = $request->user()->bikes()->findOrFail($id);
        $bike->update($request->validated());

        return new BikeResource($bike);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Request $request, string $id)
    {
        $bike = $request->user()->bikes()->findOrFail($id);
        $bike->delete();

        return response()->json(null, 204);
    }
}
