#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const YOUTRACK_URL = process.env.YOUTRACK_URL;
const YOUTRACK_TOKEN = process.env.YOUTRACK_TOKEN;

if (!YOUTRACK_URL || !YOUTRACK_TOKEN) {
  console.error("Error: YOUTRACK_URL and YOUTRACK_TOKEN environment variables are required");
  process.exit(1);
}

const BASE_URL = YOUTRACK_URL.replace(/\/$/, "");

async function youtrackRequest(endpoint, options = {}) {
  const url = `${BASE_URL}/api${endpoint}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      "Authorization": `Bearer ${YOUTRACK_TOKEN}`,
      "Accept": "application/json",
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`YouTrack API error (${response.status}): ${errorText}`);
  }

  return response.json();
}

const TOOLS = [
  {
    name: "get_issue",
    description: "Retrieve a YouTrack issue by its ID. Returns issue details including summary, description, state, assignee, and custom fields.",
    inputSchema: {
      type: "object",
      properties: {
        issueId: {
          type: "string",
          description: "The issue ID (e.g., 'PROJECT-123')",
        },
        fields: {
          type: "string",
          description: "Comma-separated list of fields to return. Default: id,idReadable,summary,description,state,assignee,reporter,created,updated,resolved,priority,type,tags,customFields",
        },
      },
      required: ["issueId"],
    },
  },
  {
    name: "get_issue_comments",
    description: "Retrieve all comments for a YouTrack issue.",
    inputSchema: {
      type: "object",
      properties: {
        issueId: {
          type: "string",
          description: "The issue ID (e.g., 'PROJECT-123')",
        },
      },
      required: ["issueId"],
    },
  },
  {
    name: "get_issue_activities",
    description: "Retrieve the activity history for a YouTrack issue. Shows changes like status updates, assignments, comments, etc.",
    inputSchema: {
      type: "object",
      properties: {
        issueId: {
          type: "string",
          description: "The issue ID (e.g., 'PROJECT-123')",
        },
        categories: {
          type: "string",
          description: "Comma-separated activity categories to filter. Options: CommentsCategory, AttachmentsCategory, CustomFieldCategory, DescriptionCategory, IssueCreatedCategory, IssueResolvedCategory, LinksCategory, ProjectCategory, SprintCategory, SummaryCategory, TagsCategory, VotersCategory, WorkItemCategory",
        },
      },
      required: ["issueId"],
    },
  },
  {
    name: "search_issues",
    description: "Search for YouTrack issues using a query. Uses YouTrack query syntax.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "YouTrack search query (e.g., 'project: MyProject state: Open', 'assignee: me', '#unresolved')",
        },
        top: {
          type: "number",
          description: "Maximum number of issues to return (default: 10, max: 100)",
        },
        skip: {
          type: "number",
          description: "Number of issues to skip for pagination (default: 0)",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "get_projects",
    description: "List all accessible YouTrack projects.",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "get_issue_attachments",
    description: "Retrieve all attachments for a YouTrack issue. Returns attachment details including name, URL, size, and mime type.",
    inputSchema: {
      type: "object",
      properties: {
        issueId: {
          type: "string",
          description: "The issue ID (e.g., 'PROJECT-123')",
        },
      },
      required: ["issueId"],
    },
  },
  {
    name: "create_issue",
    description: "Create a new YouTrack issue in a specified project. Returns the created issue details including its ID.",
    inputSchema: {
      type: "object",
      properties: {
        project: {
          type: "string",
          description: "The project short name where the issue will be created (e.g., 'VASCO', 'PROJECT')",
        },
        summary: {
          type: "string",
          description: "The issue title/summary",
        },
        description: {
          type: "string",
          description: "The issue description (supports markdown)",
        },
        type: {
          type: "string",
          description: "The issue type (e.g., 'Bug', 'Feature', 'Task'). Must match available types in the project.",
        },
        priority: {
          type: "string",
          description: "The issue priority (e.g., 'Critical', 'Major', 'Normal', 'Minor'). Must match available priorities in the project.",
        },
        assignee: {
          type: "string",
          description: "The login of the user to assign the issue to",
        },
        tags: {
          type: "array",
          items: { type: "string" },
          description: "List of tag names to add to the issue",
        },
        customFields: {
          type: "object",
          description: "Additional custom fields as key-value pairs. Use get_issue_fields_schema to discover available fields.",
        },
      },
      required: ["project", "summary"],
    },
  },
  {
    name: "get_issue_fields_schema",
    description: "Get the schema of available fields for a project. Returns all custom fields with their types and possible values (enums, users, teams, etc.). Use this before creating an issue to know what fields are available.",
    inputSchema: {
      type: "object",
      properties: {
        project: {
          type: "string",
          description: "The project short name (e.g., 'VASCO', 'PROJECT')",
        },
      },
      required: ["project"],
    },
  },
  {
    name: "find_projects",
    description: "Search for YouTrack projects by name or short name. Returns matching projects with their details.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Search query to filter projects by name or short name",
        },
        includeArchived: {
          type: "boolean",
          description: "Include archived projects in results (default: false)",
        },
      },
      required: [],
    },
  },
];

async function handleGetIssue(args) {
  const { issueId, fields } = args;
  const defaultFields = "id,idReadable,summary,description,created,updated,resolved,reporter(login,fullName),assignee(login,fullName),state(name),priority(name),type(name),tags(name),customFields(name,value(name,text,login,fullName))";
  const fieldsParam = fields || defaultFields;

  const issue = await youtrackRequest(`/issues/${issueId}?fields=${encodeURIComponent(fieldsParam)}`);
  return formatIssue(issue);
}

async function handleGetIssueComments(args) {
  const { issueId } = args;
  const comments = await youtrackRequest(
    `/issues/${issueId}/comments?fields=id,text,created,updated,author(login,fullName),deleted`
  );

  return comments
    .filter(comment => !comment.deleted)
    .map(comment => ({
      id: comment.id,
      author: comment.author?.fullName || comment.author?.login || "Unknown",
      created: new Date(comment.created).toISOString(),
      updated: comment.updated ? new Date(comment.updated).toISOString() : null,
      text: comment.text,
    }));
}

async function handleGetIssueActivities(args) {
  const { issueId, categories } = args;
  let endpoint = `/issues/${issueId}/activities?fields=id,timestamp,author(login,fullName),category(id),target(id,text,name),field(name),added(name,text,login,fullName),removed(name,text,login,fullName)`;

  if (categories) {
    endpoint += `&categories=${encodeURIComponent(categories)}`;
  }

  const activities = await youtrackRequest(endpoint);

  return activities.map(activity => ({
    id: activity.id,
    timestamp: new Date(activity.timestamp).toISOString(),
    author: activity.author?.fullName || activity.author?.login || "System",
    category: activity.category?.id,
    field: activity.field?.name,
    added: formatActivityValue(activity.added),
    removed: formatActivityValue(activity.removed),
    target: activity.target?.text || activity.target?.name,
  }));
}

async function handleSearchIssues(args) {
  const { query, top = 10, skip = 0 } = args;
  const maxTop = Math.min(top, 100);
  const fields = "id,idReadable,summary,description,created,updated,reporter(login,fullName),assignee(login,fullName),state(name),priority(name),type(name)";

  const issues = await youtrackRequest(
    `/issues?query=${encodeURIComponent(query)}&fields=${encodeURIComponent(fields)}&$top=${maxTop}&$skip=${skip}`
  );

  return issues.map(issue => formatIssue(issue));
}

async function handleGetProjects() {
  const projects = await youtrackRequest(
    "/admin/projects?fields=id,name,shortName,description,archived,leader(login,fullName)"
  );

  return projects.map(project => ({
    id: project.id,
    shortName: project.shortName,
    name: project.name,
    description: project.description,
    archived: project.archived,
    leader: project.leader?.fullName || project.leader?.login,
  }));
}

async function handleGetIssueAttachments(args) {
  const { issueId } = args;
  const attachments = await youtrackRequest(
    `/issues/${issueId}/attachments?fields=id,name,url,size,mimeType,extension,thumbnailURL,metaData,created,author(login,fullName)`
  );

  return attachments.map(attachment => ({
    id: attachment.id,
    name: attachment.name,
    url: `${BASE_URL}${attachment.url}`,
    thumbnailURL: attachment.thumbnailURL ? `${BASE_URL}${attachment.thumbnailURL}` : null,
    size: attachment.size,
    mimeType: attachment.mimeType,
    extension: attachment.extension,
    metaData: attachment.metaData,
    created: attachment.created ? new Date(attachment.created).toISOString() : null,
    author: attachment.author?.fullName || attachment.author?.login,
  }));
}

async function handleCreateIssue(args) {
  const { project, summary, description, type, priority, assignee, tags, customFields: extraCustomFields } = args;

  const issueData = {
    project: { shortName: project },
    summary: summary,
  };

  if (description) {
    issueData.description = description;
  }

  const customFields = [];

  if (type) {
    customFields.push({
      name: "Type",
      $type: "SingleEnumIssueCustomField",
      value: { name: type },
    });
  }

  if (priority) {
    customFields.push({
      name: "Priority",
      $type: "SingleEnumIssueCustomField",
      value: { name: priority },
    });
  }

  if (assignee) {
    customFields.push({
      name: "Assignee",
      $type: "SingleUserIssueCustomField",
      value: { login: assignee },
    });
  }

  if (extraCustomFields && typeof extraCustomFields === "object") {
    for (const [fieldName, fieldValue] of Object.entries(extraCustomFields)) {
      if (fieldValue === null || fieldValue === undefined) continue;

      if (Array.isArray(fieldValue)) {
        customFields.push({
          name: fieldName,
          $type: "MultiEnumIssueCustomField",
          value: fieldValue.map(v => ({ name: v })),
        });
      } else if (typeof fieldValue === "object" && fieldValue.login) {
        customFields.push({
          name: fieldName,
          $type: "SingleUserIssueCustomField",
          value: { login: fieldValue.login },
        });
      } else if (typeof fieldValue === "object" && fieldValue.name) {
        customFields.push({
          name: fieldName,
          $type: "SingleOwnedIssueCustomField",
          value: { name: fieldValue.name },
        });
      } else {
        customFields.push({
          name: fieldName,
          $type: "SingleEnumIssueCustomField",
          value: { name: String(fieldValue) },
        });
      }
    }
  }

  if (customFields.length > 0) {
    issueData.customFields = customFields;
  }

  const fields = "id,idReadable,summary,description,created,reporter(login,fullName),assignee(login,fullName),state(name),priority(name),type(name),customFields(name,value(name,text,login,fullName))";

  const createdIssue = await youtrackRequest(
    `/issues?fields=${encodeURIComponent(fields)}`,
    {
      method: "POST",
      body: JSON.stringify(issueData),
    }
  );

  if (tags && tags.length > 0) {
    for (const tagName of tags) {
      try {
        await youtrackRequest(
          `/issues/${createdIssue.idReadable}/tags?fields=id,name`,
          {
            method: "POST",
            body: JSON.stringify({ name: tagName }),
          }
        );
      } catch (error) {
        console.error(`Warning: Could not add tag "${tagName}": ${error.message}`);
      }
    }
  }

  return formatIssue(createdIssue);
}

async function handleGetIssueFieldsSchema(args) {
  const { project } = args;

  const projectData = await youtrackRequest(
    `/admin/projects?query=${encodeURIComponent(project)}&fields=id,shortName,name`
  );

  if (!projectData || projectData.length === 0) {
    throw new Error(`Project "${project}" not found`);
  }

  const projectId = projectData[0].id;

  const customFields = await youtrackRequest(
    `/admin/projects/${projectId}/customFields?fields=id,field(id,name,fieldType(id,presentation)),canBeEmpty,emptyFieldText,bundle(id,values(id,name,description,login,fullName,color(id,background,foreground)))`
  );

  const schema = {
    project: {
      id: projectData[0].id,
      shortName: projectData[0].shortName,
      name: projectData[0].name,
    },
    fields: [],
  };

  for (const cf of customFields) {
    const fieldInfo = {
      name: cf.field?.name,
      type: cf.field?.fieldType?.presentation || cf.field?.fieldType?.id,
      required: !cf.canBeEmpty,
      emptyText: cf.emptyFieldText,
    };

    if (cf.bundle?.values && cf.bundle.values.length > 0) {
      fieldInfo.values = cf.bundle.values.map(v => {
        const valueInfo = { name: v.name };
        if (v.description) valueInfo.description = v.description;
        if (v.login) valueInfo.login = v.login;
        if (v.fullName) valueInfo.fullName = v.fullName;
        return valueInfo;
      });
    }

    schema.fields.push(fieldInfo);
  }

  return schema;
}

async function handleFindProjects(args) {
  const { query, includeArchived = false } = args;

  let endpoint = "/admin/projects?fields=id,name,shortName,description,archived,leader(login,fullName)";

  const projects = await youtrackRequest(endpoint);

  let filtered = projects;

  if (!includeArchived) {
    filtered = filtered.filter(p => !p.archived);
  }

  if (query) {
    const lowerQuery = query.toLowerCase();
    filtered = filtered.filter(p =>
      p.name?.toLowerCase().includes(lowerQuery) ||
      p.shortName?.toLowerCase().includes(lowerQuery)
    );
  }

  return filtered.map(project => ({
    id: project.id,
    shortName: project.shortName,
    name: project.name,
    description: project.description,
    archived: project.archived,
    leader: project.leader?.fullName || project.leader?.login,
  }));
}

function formatIssue(issue) {
  const formatted = {
    id: issue.idReadable || issue.id,
    summary: issue.summary,
    description: issue.description,
    state: issue.state?.name,
    priority: issue.priority?.name,
    type: issue.type?.name,
    reporter: issue.reporter?.fullName || issue.reporter?.login,
    assignee: issue.assignee?.fullName || issue.assignee?.login,
    created: issue.created ? new Date(issue.created).toISOString() : null,
    updated: issue.updated ? new Date(issue.updated).toISOString() : null,
    resolved: issue.resolved ? new Date(issue.resolved).toISOString() : null,
    tags: issue.tags?.map(tag => tag.name) || [],
  };

  if (issue.customFields && issue.customFields.length > 0) {
    formatted.customFields = {};
    for (const field of issue.customFields) {
      const value = field.value;
      if (value === null || value === undefined) {
        formatted.customFields[field.name] = null;
      } else if (Array.isArray(value)) {
        formatted.customFields[field.name] = value.map(v => v.name || v.text || v.login || v.fullName || v);
      } else if (typeof value === "object") {
        formatted.customFields[field.name] = value.name || value.text || value.login || value.fullName || value;
      } else {
        formatted.customFields[field.name] = value;
      }
    }
  }

  return formatted;
}

function formatActivityValue(value) {
  if (!value) return null;
  if (Array.isArray(value)) {
    return value.map(v => v.name || v.text || v.login || v.fullName || v);
  }
  return value.name || value.text || value.login || value.fullName || value;
}

const server = new Server(
  {
    name: "youtrack",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result;

    switch (name) {
      case "get_issue":
        result = await handleGetIssue(args);
        break;
      case "get_issue_comments":
        result = await handleGetIssueComments(args);
        break;
      case "get_issue_activities":
        result = await handleGetIssueActivities(args);
        break;
      case "search_issues":
        result = await handleSearchIssues(args);
        break;
      case "get_projects":
        result = await handleGetProjects();
        break;
      case "get_issue_attachments":
        result = await handleGetIssueAttachments(args);
        break;
      case "create_issue":
        result = await handleCreateIssue(args);
        break;
      case "get_issue_fields_schema":
        result = await handleGetIssueFieldsSchema(args);
        break;
      case "find_projects":
        result = await handleFindProjects(args);
        break;
      default:
        throw new Error(`Unknown tool: ${name}`);
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("YouTrack MCP server started");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
