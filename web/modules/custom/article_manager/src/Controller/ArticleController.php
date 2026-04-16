<?php

declare(strict_types=1);

namespace Drupal\article_manager\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Database\Connection;
use Drupal\Core\Link;
use Drupal\Core\Url;
use Drupal\Core\Datetime\DateFormatterInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Contrôleur principal du module Article Manager.
 *
 * Gère l'affichage de la liste et du détail des articles.
 */
final class ArticleController extends ControllerBase {

  /**
   * Nombre d'articles par page.
   */
  const ITEMS_PER_PAGE = 15;

  /**
   * Constructeur avec injection de dépendances.
   */
  public function __construct(
    private readonly Connection $database,
    private readonly DateFormatterInterface $dateFormatter,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('database'),
      $container->get('date.formatter'),
    );
  }

  /**
   * Affiche la liste paginée des articles.
   *
   * @return array
   *   Render array Drupal.
   */
  public function list(): array {
    $build = [];

    // ── Bouton de création ─────────────────────────────────────────────────
    if ($this->currentUser()->hasPermission('manage articles')) {
      $build['add_button'] = [
        '#type'       => 'link',
        '#title'      => $this->t('+ Créer un article'),
        '#url'        => Url::fromRoute('article_manager.create'),
        '#attributes' => [
          'class' => ['button', 'button--primary', 'button--action'],
        ],
        '#prefix' => '<div class="article-manager-actions">',
        '#suffix' => '</div>',
      ];
    }

    // ── Compteur total ────────────────────────────────────────────────────
    $total = (int) $this->database->select('article_manager_articles', 'a')
      ->countQuery()
      ->execute()
      ->fetchField();

    // ── Paginateur ────────────────────────────────────────────────────────
    $page  = \Drupal::request()->query->getInt('page', 0);
    $offset = $page * self::ITEMS_PER_PAGE;

    // ── Requête principale ────────────────────────────────────────────────
    $articles = $this->database->select('article_manager_articles', 'a')
      ->fields('a', ['id', 'title', 'category', 'status', 'author_uid', 'created', 'updated'])
      ->orderBy('a.created', 'DESC')
      ->range($offset, self::ITEMS_PER_PAGE)
      ->execute()
      ->fetchAll();

    // ── Construction du tableau ───────────────────────────────────────────
    $rows = [];
    foreach ($articles as $article) {
      $author = \Drupal\user\Entity\User::load($article->author_uid);

      $operations = [];
      $operations['view'] = [
        'title' => $this->t('Voir'),
        'url'   => Url::fromRoute('article_manager.view', ['article_id' => $article->id]),
      ];
      if ($this->currentUser()->hasPermission('manage articles')) {
        $operations['edit'] = [
          'title' => $this->t('Modifier'),
          'url'   => Url::fromRoute('article_manager.edit', ['article_id' => $article->id]),
        ];
        $operations['delete'] = [
          'title'      => $this->t('Supprimer'),
          'url'        => Url::fromRoute('article_manager.delete', ['article_id' => $article->id]),
          'attributes' => ['class' => ['button--danger']],
        ];
      }

      $rows[] = [
        'id'       => $article->id,
        'title'    => Link::fromTextAndUrl($article->title, Url::fromRoute('article_manager.view', ['article_id' => $article->id])),
        'category' => $article->category ?: '—',
        'status'   => $article->status
          ? ['data' => ['#markup' => '<span class="status-badge status-published">' . $this->t('Publié') . '</span>']]
          : ['data' => ['#markup' => '<span class="status-badge status-draft">' . $this->t('Brouillon') . '</span>']],
        'author'   => $author ? $author->getDisplayName() : $this->t('Inconnu'),
        'created'  => $this->dateFormatter->format($article->created, 'short'),
        'ops'      => ['data' => ['#type' => 'operations', '#links' => $operations]],
      ];
    }

    $build['table'] = [
      '#type'   => 'table',
      '#header' => [
        '#'           => $this->t('#'),
        'title'       => $this->t('Titre'),
        'category'    => $this->t('Catégorie'),
        'status'      => $this->t('Statut'),
        'author'      => $this->t('Auteur'),
        'created'     => $this->t('Créé le'),
        'operations'  => $this->t('Actions'),
      ],
      '#rows'   => $rows,
      '#empty'  => $this->t('Aucun article. <a href=":url">Créer le premier article</a>.', [
        ':url' => Url::fromRoute('article_manager.create')->toString(),
      ]),
      '#attributes' => ['class' => ['article-manager-table']],
    ];

    // ── Pagination ────────────────────────────────────────────────────────
    $build['pager'] = [
      '#type'     => 'pager',
      '#quantity' => 5,
    ];

    \Drupal::service('pager.manager')->createPager($total, self::ITEMS_PER_PAGE);

    // ── CSS attaché ───────────────────────────────────────────────────────
    $build['#attached']['library'][] = 'article_manager/article_manager.styles';

    return $build;
  }

  /**
   * Affiche le détail d'un article.
   *
   * @param int $article_id
   *   L'identifiant de l'article.
   *
   * @return array
   *   Render array Drupal.
   *
   * @throws \Symfony\Component\HttpKernel\Exception\NotFoundHttpException
   */
  public function view(int $article_id): array {
    $article = $this->database->select('article_manager_articles', 'a')
      ->fields('a')
      ->condition('a.id', $article_id)
      ->execute()
      ->fetchObject();

    if (!$article) {
      throw new NotFoundHttpException();
    }

    $author = \Drupal\user\Entity\User::load($article->author_uid);

    $build = [
      '#theme'    => 'article_manager_detail',
      '#article'  => $article,
      '#author'   => $author ? $author->getDisplayName() : $this->t('Inconnu'),
      '#created'  => $this->dateFormatter->format($article->created, 'long'),
      '#updated'  => $this->dateFormatter->format($article->updated, 'long'),
      '#attached' => ['library' => ['article_manager/article_manager.styles']],
    ];

    // ── Boutons d'action ──────────────────────────────────────────────────
    $build['#back_url']   = Url::fromRoute('article_manager.list')->toString();
    if ($this->currentUser()->hasPermission('manage articles')) {
      $build['#edit_url']   = Url::fromRoute('article_manager.edit', ['article_id' => $article_id])->toString();
      $build['#delete_url'] = Url::fromRoute('article_manager.delete', ['article_id' => $article_id])->toString();
    }

    return $build;
  }

}
