// Fill out your copyright notice in the Description page of Project Settings.

#include "PatrolVisualizer.h"

#include "Kismet/KismetMathLibrary.h"

#include "CatBoomerShooter/AI/Patrol/PatrolPoint.h"

void FPatrolVisualizer::DrawVisualization(const UActorComponent* Component, const FSceneView* View, FPrimitiveDrawInterface* PDI)
{
    const UPatrolComponent* Patrol = Cast<UPatrolComponent>(Component);
    if (!Patrol)
        return;

    if (Patrol->PatrolPoints.Num() > 1) {
        DrawPatrol(Patrol, PDI);
        return;
    }

    if (Patrol->WanderRandomly) {
        FVector Origin;
        switch (Patrol->WanderAroundSpawnPoint) {
        case true: {
            if (UWorld* World = Component->GetWorld()) {
                if (World->WorldType != EWorldType::Editor) {
                    Origin = Patrol->ActorSpawnPoint + FVector(0., 0., 25.);
                    break;
                }
            }
        }
        case false:
            Origin = Patrol->GetOwner()->GetActorLocation() + FVector(0., 0., 25.);
            break;
        }

        DrawWireCylinder(
            PDI,
            Origin,
            FVector::UnitX(),
            FVector::UnitY(),
            FVector::UnitZ(),
            FColorList::Red,
            Patrol->WanderRange,
            25., // Height
            6, // Num sides
            100 // Depth Priority
        );
    }
}

void FPatrolVisualizer::DrawPatrol(const UPatrolComponent* PatrolComponent, FPrimitiveDrawInterface* PDI)
{
    const TArray<FPatrolData> PatrolPoints = PatrolComponent->PatrolPoints;

    for (int x = 0; x < PatrolPoints.Num() - 1; x++) {
        const FPatrolData PointData = PatrolPoints[x];

        if (!PointData.PatrolPoint)
            continue;

        DrawPoint(PointData, PDI);

        // Get next valid point
        const APatrolPoint* NextPoint = nullptr;
        while (x < PatrolPoints.Num() - 1) {
            NextPoint = PatrolPoints[x + 1].PatrolPoint;
            if (NextPoint)
                break;

            x++;
        }
        if (!NextPoint)
            continue;

        DrawConnection(PointData.PatrolPoint, NextPoint, PDI);
    }

    const APatrolPoint* FirstPoint = PatrolPoints[0].PatrolPoint;
    const FPatrolData LastPointData = PatrolPoints.Last();
    const APatrolPoint* LastPoint = LastPointData.PatrolPoint;

    if (LastPoint) {
        DrawPoint(LastPointData, PDI);
        if (FirstPoint)
            DrawConnection(LastPoint, FirstPoint, PDI);
    }
}

void FPatrolVisualizer::DrawPoint(const FPatrolData Point, FPrimitiveDrawInterface* PDI)
{
    const FVector StartPos = Point.PatrolPoint->GetActorLocation() + FVector(0., 0., 25.);
    const FRotator Rotation = Point.PatrolPoint->GetActorRotation();
    float Angle = Rotation.Euler().Z;

    DrawWireCylinder(
        PDI,
        StartPos,
        FVector::UnitX(),
        FVector::UnitY(),
        FVector::UnitZ(),
        FColorList::Red,
        Point.PatrolPointRange,
        25., // Height
        6, // Num sides
        100 // Depth Priority
    );

    if (Point.UsePatrolPointRotation) {
        DrawArc(
            PDI,
            StartPos,
            FVector::UnitX(),
            FVector::UnitY(),
            Angle - Point.RotationVariance,
            Angle + Point.RotationVariance,
            Point.PatrolPointRange * 0.8,
            4,
            FColorList::Blue,
            100);
    }
}

void FPatrolVisualizer::DrawConnection(const APatrolPoint* StartPoint, const APatrolPoint* EndPoint, FPrimitiveDrawInterface* PDI)
{
    const FVector Start = StartPoint->GetActorLocation();
    const FVector End = EndPoint->GetActorLocation();

    const FRotator Rotation = UKismetMathLibrary::FindLookAtRotation(Start, End);
    const float Distance = FVector::Distance(Start, End) * 0.8f;

    const FTransform Transform = FTransform(Rotation, Start + FVector(0., 0., 25.), FVector::One());

    Transform.ToMatrixNoScale();

    DrawDirectionalArrow(
        PDI,
        Transform.ToMatrixNoScale(),
        FColorList::Orange,
        Distance,
        5.f, // Arrow Size
        100, // Depth Priority
        5.f // Thickness
    );
}
