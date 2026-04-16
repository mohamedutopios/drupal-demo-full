<?php

declare(strict_types=1);

namespace Drupal\article_manager\Form;

use Drupal\Core\Form\ConfirmFormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Database\Connection;
use Drupal\Core\Url;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Formulaire de confirmation de suppression d'un article.
 */
final class ArticleDeleteForm extends ConfirmFormBase {

  /**
   * L'article à supprimer.
   */
  private object $article;

  /**
   * Constructeur avec injection de dépendances.
   */
  public function __construct(
    private readonly Connection $database,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('database'));
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId(): string {
    return 'article_manager_delete_form';
  }

  /**
   * {@inheritdoc}
   */
  public function getQuestion(): \Drupal\Core\StringTranslation\TranslatableMarkup {
    return $this->t('Supprimer l\'article "@title" ?', ['@title' => $this->article->title]);
  }

  /**
   * {@inheritdoc}
   */
  public function getDescription(): \Drupal\Core\StringTranslation\TranslatableMarkup {
    return $this->t('Cette action est <strong>irréversible</strong>. L\'article sera définitivement supprimé de la base de données.');
  }

  /**
   * {@inheritdoc}
   */
  public function getConfirmText(): \Drupal\Core\StringTranslation\TranslatableMarkup {
    return $this->t('Oui, supprimer');
  }

  /**
   * {@inheritdoc}
   */
  public function getCancelText(): \Drupal\Core\StringTranslation\TranslatableMarkup {
    return $this->t('Annuler');
  }

  /**
   * {@inheritdoc}
   */
  public function getCancelUrl(): Url {
    return Url::fromRoute('article_manager.view', ['article_id' => $this->article->id]);
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state, ?int $article_id = NULL): array {
    $article = $this->database->select('article_manager_articles', 'a')
      ->fields('a')
      ->condition('a.id', $article_id)
      ->execute()
      ->fetchObject();

    if (!$article) {
      throw new NotFoundHttpException();
    }

    $this->article = $article;

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $title = $this->article->title;

    $this->database->delete('article_manager_articles')
      ->condition('id', $this->article->id)
      ->execute();

    $this->messenger()->addStatus(
      $this->t('L\'article <strong>@title</strong> a été supprimé.', ['@title' => $title])
    );

    $form_state->setRedirect('article_manager.list');
  }

}
