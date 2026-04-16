<?php

declare(strict_types=1);

namespace Drupal\article_manager\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Database\Connection;
use Drupal\Core\Url;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Formulaire de création et de modification d'un article.
 *
 * Ce formulaire gère les deux cas :
 *  - Création (article_id = null)
 *  - Modification (article_id fourni via la route)
 */
final class ArticleForm extends FormBase {

  /**
   * Les catégories disponibles pour un article.
   */
  const CATEGORIES = [
    ''           => '— Choisir une catégorie —',
    'actualite'  => 'Actualité',
    'tutoriel'   => 'Tutoriel',
    'annonce'    => 'Annonce',
    'autre'      => 'Autre',
  ];

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
    return 'article_manager_article_form';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state, ?int $article_id = NULL): array {
    // Chargement de l'article existant si modification
    $article = NULL;
    if ($article_id) {
      $article = $this->database->select('article_manager_articles', 'a')
        ->fields('a')
        ->condition('a.id', $article_id)
        ->execute()
        ->fetchObject();

      if (!$article) {
        $this->messenger()->addError($this->t('Article introuvable.'));
        return $form;
      }
    }

    // Stockage de l'ID pour le submit
    $form_state->set('article_id', $article_id);

    $form['#prefix'] = '<div class="article-manager-form">';
    $form['#suffix'] = '</div>';

    // ── Titre ─────────────────────────────────────────────────────────────
    $form['title'] = [
      '#type'          => 'textfield',
      '#title'         => $this->t('Titre'),
      '#required'      => TRUE,
      '#maxlength'     => 255,
      '#default_value' => $article->title ?? '',
      '#placeholder'   => $this->t('Saisissez le titre de l\'article'),
      '#attributes'    => ['autofocus' => 'autofocus'],
    ];

    // ── Catégorie ─────────────────────────────────────────────────────────
    $form['category'] = [
      '#type'          => 'select',
      '#title'         => $this->t('Catégorie'),
      '#options'       => self::CATEGORIES,
      '#default_value' => $article->category ?? '',
    ];

    // ── Corps ─────────────────────────────────────────────────────────────
    $form['body'] = [
      '#type'          => 'textarea',
      '#title'         => $this->t('Contenu'),
      '#rows'          => 12,
      '#default_value' => $article->body ?? '',
      '#placeholder'   => $this->t('Rédigez le contenu de votre article...'),
    ];

    // ── Statut ────────────────────────────────────────────────────────────
    $form['status'] = [
      '#type'          => 'radios',
      '#title'         => $this->t('Statut de publication'),
      '#options'       => [
        1 => $this->t('Publié'),
        0 => $this->t('Brouillon'),
      ],
      '#default_value' => isset($article->status) ? (int) $article->status : 1,
    ];

    // ── Actions ───────────────────────────────────────────────────────────
    $form['actions'] = [
      '#type'       => 'actions',
    ];

    $form['actions']['submit'] = [
      '#type'  => 'submit',
      '#value' => $article_id
        ? $this->t('💾 Enregistrer les modifications')
        : $this->t('✅ Créer l\'article'),
      '#attributes' => ['class' => ['button--primary']],
    ];

    $form['actions']['cancel'] = [
      '#type'       => 'link',
      '#title'      => $this->t('Annuler'),
      '#url'        => $article_id
        ? Url::fromRoute('article_manager.view', ['article_id' => $article_id])
        : Url::fromRoute('article_manager.list'),
      '#attributes' => ['class' => ['button']],
    ];

    $form['#attached']['library'][] = 'article_manager/article_manager.styles';

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function validateForm(array &$form, FormStateInterface $form_state): void {
    $title = trim($form_state->getValue('title'));

    if (strlen($title) < 3) {
      $form_state->setErrorByName('title', $this->t('Le titre doit comporter au moins 3 caractères.'));
    }

    if (strlen($title) > 255) {
      $form_state->setErrorByName('title', $this->t('Le titre ne peut pas dépasser 255 caractères.'));
    }
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $article_id = $form_state->get('article_id');
    $now        = \Drupal::time()->getRequestTime();
    $uid        = $this->currentUser()->id();

    $data = [
      'title'      => trim($form_state->getValue('title')),
      'body'       => $form_state->getValue('body'),
      'category'   => $form_state->getValue('category'),
      'status'     => (int) $form_state->getValue('status'),
      'updated'    => $now,
    ];

    if ($article_id) {
      // ── Mise à jour ──────────────────────────────────────────────────
      $this->database->update('article_manager_articles')
        ->fields($data)
        ->condition('id', $article_id)
        ->execute();

      $this->messenger()->addStatus(
        $this->t('Article <strong>@title</strong> modifié avec succès.', ['@title' => $data['title']])
      );

      $form_state->setRedirect('article_manager.view', ['article_id' => $article_id]);
    }
    else {
      // ── Création ─────────────────────────────────────────────────────
      $data['author_uid'] = $uid;
      $data['created']    = $now;

      $new_id = $this->database->insert('article_manager_articles')
        ->fields($data)
        ->execute();

      $this->messenger()->addStatus(
        $this->t('Article <strong>@title</strong> créé avec succès.', ['@title' => $data['title']])
      );

      $form_state->setRedirect('article_manager.view', ['article_id' => $new_id]);
    }
  }

}
