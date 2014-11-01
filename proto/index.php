<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <link href="http://maxcdn.bootstrapcdn.com/font-awesome/4.2.0/css/font-awesome.min.css" rel="stylesheet"/>
    <link href="screen.css" rel="stylesheet"/>
  </head>
  <body>
    <div class="body">
      <div class="par">
        <a href="/">home</a>
        <a href="/submit">submit</a>
        <a href="/acc">$78.90</a>
        <a href="/terms">terms</a>
        <span>@yegor256</span>
        <a href="/"><i class="fa fa-sign-out"></i></a>
      </div>
      <div class="par">
        <form action="/" method="post">
          <fieldset class="inline">
            <input name="q" size="30" value="name:Yegor"/>
            <button type="submit"><i class="fa fa-search"></i></button>
          </fieldset>
        </form>
      </div>
      <?php $page = substr($_SERVER['REQUEST_URI'], 1);
      if (empty($page)) {
        $page = 'index';
      }
      include (__DIR__ . '/' . $page . '.phtml');
      ?>
    </div>
  </body>
</html>

