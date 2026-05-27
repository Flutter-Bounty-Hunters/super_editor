async function run() {
  const { Octokit } = await import("@octokit/action");
  const { GoogleGenerativeAI } = await import("@google/generative-ai");

  const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  const [owner, repo] = process.env.GITHUB_REPOSITORY.split("/");
  const pr_number = parseInt(process.env.PR_NUMBER);

  if (!GITHUB_TOKEN || !GEMINI_API_KEY || !pr_number) {
    console.error("Missing required environment variables.");
    process.exit(1);
  }

  const octokit = new Octokit();
  const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-pro" });

  // 1. Get PR diff
  const { data: diff } = await octokit.rest.pulls.get({
    owner,
    repo,
    pull_number: pr_number,
    mediaType: { format: "diff" },
  });

  // 2. Prepare the prompt
  const prompt = `
You are a strict Dart and Flutter code reviewer. Review the following PR diff and identify violations of the following strict guidelines:

1) Single-line if-statements are strictly forbidden; always use braces for the block.
2) Class members must be ordered: Static properties, Static methods, Factory constructors, Named constructors, Default constructors, Instance Properties, Instance Methods, toString(), then hashCode/==.
3) Within groups, order from high-level to low-level (most important/complex first), and public to private.
4) Never allow the use of the words "helper" or "utility" for naming classes, methods, or files; demand meaningful domain-specific names.

### PR DIFF:
${diff}

### OUTPUT FORMAT:
Output your review as a JSON array of objects. Each object represents a violation and MUST have:
- "path": The file path (e.g., "lib/main.dart")
- "line": The line number in the NEW version of the file where the violation occurs.
- "body": A concise explanation of the violation and how to fix it.

Example:
[
  {"path": "lib/util.dart", "line": 5, "body": "The word 'util' is forbidden in file names. Use a domain-specific name instead."},
  {"path": "lib/widgets.dart", "line": 12, "body": "Single-line if-statement detected. Wrap the block in braces { ... }."}
]

If no violations are found, return an empty array [].
Respond ONLY with the JSON array.
`;

  // 3. Get Gemini's review
  const result = await model.generateContent(prompt);
  const response = await result.response;
  let text = response.text().trim();

  // Clean up markdown code blocks if present
  if (text.startsWith("```json")) {
    text = text.substring(7, text.length - 3).trim();
  } else if (text.startsWith("```")) {
    text = text.substring(3, text.length - 3).trim();
  }

  let violations = [];
  try {
    violations = JSON.parse(text);
  } catch (e) {
    console.error("Failed to parse Gemini response as JSON:", text);
    process.exit(1);
  }

  if (violations.length === 0) {
    console.log("No violations found.");
    return;
  }

  // 4. Post comments to GitHub
  // We'll post a review with multiple comments
  const comments = violations.map(v => ({
    path: v.path,
    line: v.line,
    body: v.body,
  }));

  try {
    await octokit.rest.pulls.createReview({
      owner,
      repo,
      pull_number: pr_number,
      event: "COMMENT",
      body: "AI Code Review Summary: Found some style violations. Please address them.",
      comments: comments,
    });
    console.log(`Successfully posted ${violations.length} comments.`);
  } catch (e) {
    console.error("Failed to post review comments:", e);
    // Fallback: post a single top-level comment if inline comments fail
    const summary = violations.map(v => `- **${v.path}:${v.line}**: ${v.body}`).join("\n");
    await octokit.rest.issues.createComment({
      owner,
      repo,
      issue_number: pr_number,
      body: `### AI Code Review Violations:\n${summary}`,
    });
  }
}

run();
