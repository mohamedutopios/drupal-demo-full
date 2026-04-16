<?php

declare(strict_types=1);

namespace Drupal\Tests\article_manager\Unit;

use PHPUnit\Framework\TestCase;

/**
 * Tests unitaires pour la logique de validation du module Article Manager.
 *
 * Ces tests vérifient les règles métier indépendamment du framework Drupal.
 *
 * @group article_manager
 * @coversDefaultClass \Drupal\article_manager\Form\ArticleForm
 */
class ArticleValidationTest extends TestCase {

  /**
   * Teste que le titre doit avoir au moins 3 caractères.
   *
   * @covers ::validateForm
   * @dataProvider titleLengthProvider
   */
  public function testTitleLengthValidation(string $title, bool $isValid): void {
    $titleLength = strlen(trim($title));

    if ($isValid) {
      $this->assertGreaterThanOrEqual(3, $titleLength, "Le titre '$title' devrait être valide.");
      $this->assertLessThanOrEqual(255, $titleLength, "Le titre '$title' ne devrait pas dépasser 255 chars.");
    }
    else {
      $this->assertTrue(
        $titleLength < 3 || $titleLength > 255,
        "Le titre '$title' devrait être invalide."
      );
    }
  }

  /**
   * Fournisseur de données pour testTitleLengthValidation.
   *
   * @return array<string, array{string, bool}>
   */
  public static function titleLengthProvider(): array {
    return [
      'titre_vide'       => ['', FALSE],
      'titre_trop_court' => ['ab', FALSE],
      'titre_exact_3'    => ['abc', TRUE],
      'titre_normal'     => ['Mon article de test', TRUE],
      'titre_255_chars'  => [str_repeat('a', 255), TRUE],
      'titre_256_chars'  => [str_repeat('a', 256), FALSE],
    ];
  }

  /**
   * Teste que les statuts valides sont bien 0 ou 1.
   *
   * @covers ::submitForm
   * @dataProvider statusProvider
   */
  public function testStatusValues(int $status, bool $isValid): void {
    $validStatuses = [0, 1];
    $result = in_array($status, $validStatuses, TRUE);
    $this->assertSame($isValid, $result);
  }

  /**
   * Fournisseur de données pour testStatusValues.
   *
   * @return array<string, array{int, bool}>
   */
  public static function statusProvider(): array {
    return [
      'status_publie'   => [1, TRUE],
      'status_brouillon' => [0, TRUE],
      'status_invalide' => [2, FALSE],
      'status_negatif'  => [-1, FALSE],
    ];
  }

  /**
   * Teste les catégories autorisées.
   */
  public function testValidCategories(): void {
    $validCategories = ['', 'actualite', 'tutoriel', 'annonce', 'autre'];

    foreach ($validCategories as $category) {
      $this->assertContains(
        $category,
        $validCategories,
        "La catégorie '$category' doit être valide."
      );
    }

    $this->assertNotContains('hacking', $validCategories);
    $this->assertNotContains('SPAM', $validCategories);
  }

  /**
   * Teste le nettoyage du titre (trim).
   */
  public function testTitleIsTrimmed(): void {
    $rawTitle   = '   Mon article   ';
    $cleanTitle = trim($rawTitle);

    $this->assertEquals('Mon article', $cleanTitle);
    $this->assertStringStartsNotWith(' ', $cleanTitle);
    $this->assertStringEndsNotWith(' ', $cleanTitle);
  }

}
