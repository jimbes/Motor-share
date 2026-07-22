<?php

namespace App\Services;

class PolylineSimplifier
{
    /**
     * Reduce a track (array of ['lat' => float, 'lng' => float, ...]) to its
     * essential points using the Ramer-Douglas-Peucker algorithm, so feed
     * responses can ship a lightweight route preview instead of the full
     * GPS trace.
     *
     * @param  array<int, array{lat: float, lng: float}>  $points
     * @return array<int, array{lat: float, lng: float}>
     */
    public function simplify(array $points, float $toleranceMeters = 15.0): array
    {
        if (count($points) <= 2) {
            return $points;
        }

        $keep = $this->douglasPeucker($points, 0, count($points) - 1, $toleranceMeters);
        sort($keep);

        return array_values(array_map(fn (int $i) => $points[$i], $keep));
    }

    /**
     * @param  array<int, array{lat: float, lng: float}>  $points
     * @return array<int, int>
     */
    private function douglasPeucker(array $points, int $start, int $end, float $tolerance): array
    {
        $maxDistance = 0.0;
        $index = -1;

        for ($i = $start + 1; $i < $end; $i++) {
            $distance = $this->perpendicularDistance($points[$i], $points[$start], $points[$end]);
            if ($distance > $maxDistance) {
                $maxDistance = $distance;
                $index = $i;
            }
        }

        if ($maxDistance > $tolerance && $index !== -1) {
            $left = $this->douglasPeucker($points, $start, $index, $tolerance);
            $right = $this->douglasPeucker($points, $index, $end, $tolerance);

            return [...$left, ...$right];
        }

        return [$start, $end];
    }

    private function perpendicularDistance(array $point, array $lineStart, array $lineEnd): float
    {
        $x = $point['lng'];
        $y = $point['lat'];
        $x1 = $lineStart['lng'];
        $y1 = $lineStart['lat'];
        $x2 = $lineEnd['lng'];
        $y2 = $lineEnd['lat'];

        $dx = $x2 - $x1;
        $dy = $y2 - $y1;

        if ($dx === 0.0 && $dy === 0.0) {
            $metersPerDegreeLat = 111_320;
            $metersPerDegreeLng = 111_320 * cos(deg2rad($y1));

            return sqrt((($x - $x1) * $metersPerDegreeLng) ** 2 + (($y - $y1) * $metersPerDegreeLat) ** 2);
        }

        $t = (($x - $x1) * $dx + ($y - $y1) * $dy) / ($dx ** 2 + $dy ** 2);
        $t = max(0, min(1, $t));

        $closestX = $x1 + $t * $dx;
        $closestY = $y1 + $t * $dy;

        $metersPerDegreeLat = 111_320;
        $metersPerDegreeLng = 111_320 * cos(deg2rad($y));

        return sqrt((($x - $closestX) * $metersPerDegreeLng) ** 2 + (($y - $closestY) * $metersPerDegreeLat) ** 2);
    }
}
