// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "AIController.h"
#include "AIEnemyBaseController.generated.h"
#include "CoreMinimal.h"
#include "GameTeams.h"

/**
 *
 */
UCLASS()
class CATBOOMERSHOOTER_API AAIEnemyBaseController : public AAIController {
    GENERATED_BODY()

public:
    AAIEnemyBaseController(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());

protected:
    virtual void BeginPlay() override;

    UPROPERTY(EditDefaultsOnly, Category = "EnemyBase")
    class UBehaviorTree* DefaultBehaviorTree;

private:
    /** Requests an enemy token of a given type.
     *	Token Priority is currently unimplemented. */
    UFUNCTION(BlueprintCallable, Category = "Tokens")
    void RequestToken(const AActor* TargetActor, const ETokenType TokenType, const ETokenPriority TokenPriority, UEnemyToken*& Token, bool& Success);

    /** Returns a token from being used by an enemy */
    UFUNCTION(BlueprintCallable, Category = "Tokens")
    void ReleaseToken(UEnemyToken* Token, const float CustomCooldown = -1.0f);

public:
    UFUNCTION(BlueprintNativeEvent, Category = "Tokens")
    void TokenRetracted(UEnemyToken* Token);

    ETeamAttitude::Type GetTeamAttitudeTowards(const AActor& Other) const override;
};
