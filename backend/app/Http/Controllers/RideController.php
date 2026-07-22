<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreRideRequest;
use App\Http\Resources\RideDetailResource;
use App\Http\Resources\RideResource;
use App\Models\Ride;
use App\Services\PolylineSimplifier;
use Illuminate\Http\Request;

class RideController extends Controller
{
    /**
     * Display a listing of the resource (the feed, newest first).
     */
    public function index(Request $request)
    {
        $rides = Ride::query()
            ->with(['user', 'bike', 'photos'])
            ->withCount(['likes', 'comments'])
            ->withExists(['likes as liked_by_me' => fn ($query) => $query->where('user_id', $request->user()->id)])
            ->latest('started_at')
            ->paginate(10);

        return RideResource::collection($rides);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreRideRequest $request, PolylineSimplifier $simplifier)
    {
        $data = $request->validated();

        $ride = $request->user()->rides()->create([
            ...$data,
            'polyline_simplified' => $simplifier->simplify($data['track']),
        ]);

        $ride->load(['user', 'bike', 'photos']);

        return new RideDetailResource($ride->loadCount(['likes', 'comments']));
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, string $id)
    {
        $ride = Ride::query()
            ->with(['user', 'bike', 'photos', 'comments.user', 'likes'])
            ->withCount(['likes', 'comments'])
            ->findOrFail($id);

        return new RideDetailResource($ride);
    }

    /**
     * Aggregate stats for the authenticated user's own rides - powers the
     * "this week" card on the feed and the stat row on the profile screen.
     */
    public function myStats(Request $request)
    {
        $rides = $request->user()->rides();

        $weekStart = now()->subDays(7);

        return response()->json([
            'rides_count' => (clone $rides)->count(),
            'distance_meters' => (int) (clone $rides)->sum('distance_meters'),
            'week_rides_count' => (clone $rides)->where('started_at', '>=', $weekStart)->count(),
            'week_distance_meters' => (int) (clone $rides)->where('started_at', '>=', $weekStart)->sum('distance_meters'),
        ]);
    }
}
