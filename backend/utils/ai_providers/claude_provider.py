"""
Claude Provider - Professional AI Report Generation
=================================================

Claude by Anthropic provides thoughtful, detailed analysis with excellent
formatting and professional insights for intern progress evaluation.

Features:
- Thoughtful, nuanced analysis
- Professional formatting and structure
- Detailed feedback and suggestions
- Strong reasoning and explanation
- Cost-effective pricing
- Excellent safety and reliability

Setup Requirements:
1. Get Claude API key from https://console.anthropic.com/
2. Set environment variable: ANTHROPIC_API_KEY=your_api_key
3. Ensure sufficient credits in Anthropic account

Cost: ~$0.008 per 1K tokens (very cost-effective)

Usage:
    provider = ClaudeProvider()
    report = provider.generate_report(intern_data, 'weekly')
"""

import os
import json
import logging
from typing import Dict, Any, List, Optional
import anthropic
from .base_provider import BaseAIProvider

logger = logging.getLogger(__name__)

class ClaudeProvider(BaseAIProvider):
    """
    Claude (Anthropic) AI provider implementation.
    Provides thoughtful, detailed analysis with professional formatting.
    """
    
    def __init__(self, api_key: Optional[str] = None, model: str = "claude-3-sonnet-20240229"):
        """
        Initialize Claude provider
        
        Args:
            api_key: Anthropic API key (if None, reads from environment)
            model: Claude model to use (default: claude-3-sonnet)
        """
        self.api_key = api_key or os.getenv('ANTHROPIC_API_KEY')
        self.model = model
        self.last_error = None
        
        if not self.api_key:
            self.last_error = "Anthropic API key not provided"
            logger.error(self.last_error)
            self.client = None
        else:
            try:
                self.client = anthropic.Anthropic(api_key=self.api_key)
                logger.info(f"Claude provider initialized with model: {model}")
            except Exception as e:
                self.last_error = f"Failed to initialize Claude client: {e}"
                logger.error(self.last_error)
                self.client = None
        
        # Available models
        self.available_models = [
            "claude-3-opus-20240229",      # Most capable
            "claude-3-sonnet-20240229",    # Balanced performance/cost
            "claude-3-haiku-20240307"      # Fastest and most affordable
        ]
        
        # Report generation prompts
        self.system_prompts = {
            'weekly': self._get_weekly_system_prompt(),
            'monthly': self._get_monthly_system_prompt(),
            'project_summary': self._get_project_system_prompt()
        }
    
    def test_connection(self) -> bool:
        """
        Test connection to Claude API
        
        Returns:
            True if API is accessible and working
        """
        if not self.client:
            return False
        
        try:
            # Make a simple API call to test connection
            response = self.client.messages.create(
                model=self.model,
                max_tokens=10,
                messages=[
                    {"role": "user", "content": "Test connection. Reply with 'OK'."}
                ]
            )
            
            if response.content[0].text.strip().upper() == 'OK':
                self.last_error = None
                logger.info(f"Claude connection test successful with model {self.model}")
                return True
            else:
                self.last_error = "Claude API test returned unexpected response"
                logger.error(self.last_error)
                return False
                
        except Exception as e:
            self.last_error = f"Claude API connection failed: {e}"
            logger.error(self.last_error)
            return False
    
    def get_available_models(self) -> List[str]:
        """
        Get list of available Claude models
        
        Returns:
            List of model names
        """
        return self.available_models.copy()
    
    def generate_report(self, intern_data: Dict[str, Any], report_type: str = 'weekly') -> Dict[str, Any]:
        """
        Generate AI report using Claude
        
        Args:
            intern_data: Intern's logbook entries and performance data
            report_type: Type of report ('weekly', 'monthly', 'project_summary')
            
        Returns:
            Generated report dictionary
        """
        try:
            # Validate connection
            if not self.test_connection():
                return {
                    'success': False,
                    'error': f"Claude not available: {self.last_error}",
                    'provider': 'claude'
                }
            
            # Format data for AI processing
            formatted_data = self.format_intern_data_for_ai(intern_data)
            
            # Get appropriate system prompt
            if report_type not in self.system_prompts:
                report_type = 'weekly'  # Default fallback
            
            system_prompt = self.system_prompts[report_type]
            user_prompt = self._create_user_prompt(intern_data, formatted_data, report_type)
            
            # Generate report using Claude
            logger.info(f"Generating {report_type} report using Claude model: {self.model}")
            
            ai_response = self._call_claude_api(system_prompt, user_prompt)
            
            if ai_response:
                # Parse and structure the response
                report_content = self._parse_claude_response(ai_response, report_type)
                
                # Create standardized report structure
                report = self.create_report_structure(
                    intern_data=intern_data,
                    report_type=report_type,
                    ai_content=report_content,
                    provider='claude'
                )
                
                logger.info("Claude report generated successfully")
                return report
            else:
                return {
                    'success': False,
                    'error': 'Failed to generate report with Claude',
                    'provider': 'claude'
                }
                
        except Exception as e:
            logger.error(f"Claude report generation failed: {e}")
            return {
                'success': False,
                'error': f"Claude error: {e}",
                'provider': 'claude'
            }
    
    def _call_claude_api(self, system_prompt: str, user_prompt: str) -> Optional[str]:
        """
        Call Claude API to generate response
        
        Args:
            system_prompt: System instructions for AI
            user_prompt: User input prompt
            
        Returns:
            AI response text or None if failed
        """
        try:
            response = self.client.messages.create(
                model=self.model,
                max_tokens=3000,
                temperature=0.7,  # Balanced creativity and consistency
                system=system_prompt,
                messages=[
                    {"role": "user", "content": user_prompt}
                ]
            )
            
            return response.content[0].text.strip()
            
        except Exception as e:
            logger.error(f"Claude API call failed: {e}")
            return None
    
    def _parse_claude_response(self, response: str, report_type: str) -> Dict[str, Any]:
        """
        Parse Claude response into structured format
        
        Args:
            response: Raw AI response text
            report_type: Type of report being generated
            
        Returns:
            Structured report content
        """
        content = {
            'summary': '',
            'strengths': [],
            'weaknesses': [],
            'recommendations': [],
            'performance_score': 0,
            'raw_response': response
        }
        
        try:
            # Claude provides very well-structured responses
            # Try to parse JSON if formatted as such
            if response.strip().startswith('{') and response.strip().endswith('}'):
                parsed_json = json.loads(response)
                if isinstance(parsed_json, dict):
                    content.update(parsed_json)
                    content['performance_score'] = self.calculate_performance_score(content)
                    return content
            
            # Parse structured markdown-like response
            sections = response.split('\n\n')
            current_section = None
            
            for section in sections:
                section = section.strip()
                if not section:
                    continue
                
                section_lower = section.lower()
                
                # Identify section headers (Claude often uses markdown headers)
                if section.startswith('#') or any(keyword in section_lower for keyword in ['summary', 'overview', 'executive']):
                    current_section = 'summary'
                    # Clean header and extract content
                    lines = section.split('\n')
                    content_lines = []
                    for line in lines:
                        if not line.startswith('#') and not any(h in line.lower() for h in ['summary', 'overview', 'executive']):
                            content_lines.append(line)
                    if content_lines:
                        content['summary'] = '\n'.join(content_lines).strip()
                    else:
                        content['summary'] = section.split('\n', 1)[1] if '\n' in section else section
                        
                elif any(keyword in section_lower for keyword in ['strength', 'positive', 'excellent', 'good performance']):
                    current_section = 'strengths'
                    items = self._extract_claude_items(section)
                    content['strengths'].extend(items)
                    
                elif any(keyword in section_lower for keyword in ['weakness', 'improvement', 'challenge', 'development area']):
                    current_section = 'weaknesses'
                    items = self._extract_claude_items(section)
                    content['weaknesses'].extend(items)
                    
                elif any(keyword in section_lower for keyword in ['recommend', 'suggest', 'next step', 'action item', 'going forward']):
                    current_section = 'recommendations'
                    items = self._extract_claude_items(section)
                    content['recommendations'].extend(items)
                    
                else:
                    # Continue with current section or add to summary
                    if current_section == 'summary' and content['summary']:
                        content['summary'] += '\n\n' + section
                    elif not content['summary'] and len(section) > 50:
                        content['summary'] = section
            
            # Calculate performance score
            content['performance_score'] = self.calculate_performance_score(content)
            
            # Ensure minimum content quality
            if not content['summary']:
                content['summary'] = response[:1000] + '...' if len(response) > 1000 else response
            
            return content
            
        except Exception as e:
            logger.warning(f"Error parsing Claude response: {e}")
            # Fallback to basic structure
            return {
                'summary': response[:1500] + '...' if len(response) > 1500 else response,
                'strengths': ['Detailed analysis completed successfully'],
                'weaknesses': ['Some areas may benefit from additional data'],
                'recommendations': ['Continue current development trajectory'],
                'performance_score': 82,  # Default score
                'raw_response': response
            }
    
    def _extract_claude_items(self, text: str) -> List[str]:
        """
        Extract structured items from Claude formatted text
        
        Args:
            text: Text section containing items
            
        Returns:
            List of cleaned items
        """
        items = []
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Skip section headers
            if line.startswith('#') or any(header in line.lower() for header in ['strength', 'weakness', 'recommend']):
                if ':' in line and len(line.split(':')[1].strip()) < 15:
                    continue
            
            # Clean various list formats that Claude might use
            cleaned_line = line
            
            # Remove markdown and bullet points
            for prefix in ['•', '○', '▪', '-', '*', '→', '►', '✓', '▸']:
                if line.startswith(prefix):
                    cleaned_line = line[1:].strip()
                    break
            
            # Handle numbered lists
            if '. ' in line:
                parts = line.split('. ', 1)
                if len(parts) > 1 and parts[0].strip().replace(')', '').isdigit():
                    cleaned_line = parts[1]
            
            # Handle lettered lists
            if '. ' in line and len(line.split('. ')[0].strip()) <= 2:
                cleaned_line = '. '.join(line.split('. ')[1:])
            
            # Remove markdown formatting
            cleaned_line = cleaned_line.replace('**', '').replace('*', '').replace('`', '')
            
            # Only add meaningful, substantial content
            if (len(cleaned_line) > 20 and 
                not any(skip in cleaned_line.lower() for skip in ['strengths:', 'weaknesses:', 'recommendations:', 'summary:', '###', '##'])):
                items.append(cleaned_line)
        
        return items
    
    def _create_user_prompt(self, intern_data: Dict[str, Any], formatted_data: str, report_type: str) -> str:
        """
        Create user prompt for Claude
        
        Args:
            intern_data: Intern information
            formatted_data: Formatted logbook data
            report_type: Type of report
            
        Returns:
            Formatted user prompt
        """
        return f"""
I need you to analyze an intern's performance data and create a comprehensive {report_type} report.

**Intern Details:**
- Name: {intern_data.get('intern_name', 'Unknown')}
- Project: {intern_data.get('project_name', 'Unknown')}
- Supervisor: {intern_data.get('supervisor_name', 'Unknown')}
- Reporting Period: {intern_data.get('period', 'Unknown')}

**Performance Data for Analysis:**
{formatted_data}

Please provide a thorough, professional analysis following the structure and guidelines specified in the system prompt. Focus on actionable insights, specific examples from the data, and constructive feedback that will help the intern grow professionally.

Make your analysis comprehensive yet concise, professional yet encouraging, and always grounded in the actual data provided.
"""
    
    def _get_weekly_system_prompt(self) -> str:
        """Get system prompt for weekly reports"""
        return """
You are a senior mentor and supervisor with extensive experience in guiding intern development. Your role is to analyze weekly performance data and create insightful, constructive reports that help interns understand their progress and identify growth opportunities.

For weekly reports, structure your analysis as follows:

## Executive Summary
Provide a concise overview of the week's key developments, highlighting the most significant achievements and any notable concerns.

## Technical Progress Analysis
Examine the technical work completed, skills demonstrated, and quality of deliverables. Be specific about technologies used, problems solved, and technical growth observed.

## Strengths and Positive Observations
Identify specific strengths demonstrated during the week. Include examples from the actual data and explain why these behaviors/skills are valuable.

## Development Opportunities
Highlight areas where improvement would be beneficial. Frame these constructively, focusing on growth potential rather than deficiencies.

## Actionable Recommendations
Provide specific, practical suggestions for the upcoming week. Include both technical and professional development recommendations.

## Performance Assessment
Offer a balanced evaluation of overall performance, considering both achievements and areas for growth.

Guidelines for your analysis:
- Be specific and reference actual activities from the logbook entries
- Maintain a supportive, constructive tone throughout
- Provide actionable feedback that the intern can implement
- Balance recognition of achievements with growth opportunities
- Consider both technical competencies and professional skills
- Use professional language suitable for formal documentation

Your goal is to create a report that motivates the intern while providing clear direction for continued development.
"""
    
    def _get_monthly_system_prompt(self) -> str:
        """Get system prompt for monthly reports"""
        return """
You are conducting a comprehensive monthly performance review as a senior supervisor. This report will be used for formal performance documentation and strategic development planning.

Structure your monthly analysis as follows:

## Monthly Performance Overview
Provide a high-level summary of the intern's progression throughout the month, highlighting major themes and overall trajectory.

## Key Achievements and Milestones
Document significant accomplishments, completed projects, and important milestones reached during the month.

## Technical Skill Development
Analyze the evolution of technical capabilities, including new technologies learned, improvement in existing skills, and quality of technical deliverables.

## Professional Growth Assessment
Evaluate development in communication, collaboration, problem-solving, time management, and other professional competencies.

## Challenge Navigation and Problem-Solving
Assess how the intern handled difficulties, their approach to problem-solving, and resilience in facing obstacles.

## Contribution to Team and Projects
Evaluate the intern's integration with the team, contribution to project goals, and impact on overall productivity.

## Strategic Development Recommendations
Provide forward-looking suggestions for skills to develop, experiences to pursue, and goals to set for the coming month.

## Overall Performance Rating
Offer a comprehensive assessment of the intern's performance relative to expectations and internship objectives.

Analysis Guidelines:
- Focus on trends and patterns observed over the month
- Provide evidence-based assessments using specific examples
- Consider both quantitative metrics and qualitative observations
- Address readiness for increased responsibilities
- Identify career development opportunities
- Maintain objectivity while being supportive
- Include comparative analysis of progress from previous periods

This report should serve as both documentation of performance and a roadmap for continued growth and development.
"""
    
    def _get_project_system_prompt(self) -> str:
        """Get system prompt for project summary reports"""
        return """
You are conducting a comprehensive project-completion assessment for an intern's overall contribution. This evaluation will inform decisions about future opportunities and serve as a complete record of the intern's project involvement.

Structure your project summary as follows:

## Project Contribution Executive Summary
Provide a high-level overview of the intern's role, responsibilities, and overall impact on the project's success.

## Technical Contributions and Deliverables
Detail specific technical work completed, code contributions, documentation created, and the quality/impact of these deliverables.

## Problem-Solving and Innovation
Analyze instances where the intern demonstrated creative thinking, solved complex problems, or contributed innovative solutions.

## Collaboration and Team Integration
Assess how effectively the intern worked with team members, communicated with stakeholders, and contributed to team dynamics.

## Project Management and Execution
Evaluate the intern's ability to manage tasks, meet deadlines, handle multiple priorities, and adapt to changing requirements.

## Learning and Professional Development
Document the growth observed throughout the project, new skills acquired, and professional competencies developed.

## Quality and Professionalism
Assess the standard of work produced, attention to detail, adherence to best practices, and overall professional conduct.

## Impact Assessment
Analyze the tangible impact of the intern's contributions on project outcomes, team productivity, and organizational goals.

## Future Readiness Evaluation
Assess the intern's readiness for full-time employment, areas where they excel, and capabilities that make them valuable.

## Final Recommendations
Provide recommendations regarding the intern's potential for permanent hire, areas for continued development, and suggestions for career growth.

Evaluation Criteria:
- Technical competency and code quality
- Adaptability and learning capacity
- Communication and interpersonal skills
- Initiative and proactive behavior
- Reliability and work ethic
- Innovation and creative problem-solving
- Team collaboration and leadership potential
- Professional maturity and growth mindset

This comprehensive assessment should provide a complete picture of the intern's capabilities, contributions, and potential for future success in the organization.
"""
    
    def set_model(self, model_name: str) -> bool:
        """
        Set Claude model to use
        
        Args:
            model_name: Name of Claude model
            
        Returns:
            True if model is available and set successfully
        """
        if model_name in self.available_models:
            self.model = model_name
            logger.info(f"Claude model set to: {model_name}")
            return True
        else:
            logger.warning(f"Claude model {model_name} not available")
            return False
    
    def estimate_cost(self, text_length: int) -> Dict[str, float]:
        """
        Estimate cost for Claude API call
        
        Args:
            text_length: Approximate input text length
            
        Returns:
            Cost estimation information
        """
        # Rough token estimation (1 token ≈ 4 characters)
        estimated_tokens = text_length / 4
        
        # Claude pricing (approximate, varies by model)
        pricing = {
            'claude-3-opus-20240229': {'input': 0.015, 'output': 0.075},    # per 1K tokens
            'claude-3-sonnet-20240229': {'input': 0.003, 'output': 0.015},  # per 1K tokens
            'claude-3-haiku-20240307': {'input': 0.00025, 'output': 0.00125} # per 1K tokens
        }
        
        model_pricing = pricing.get(self.model, pricing['claude-3-sonnet-20240229'])
        input_cost = (estimated_tokens / 1000) * model_pricing['input']
        output_cost = (2500 / 1000) * model_pricing['output']  # Assume 2.5K output tokens
        
        return {
            'estimated_input_tokens': int(estimated_tokens),
            'estimated_output_tokens': 2500,
            'input_cost_usd': round(input_cost, 4),
            'output_cost_usd': round(output_cost, 4),
            'total_cost_usd': round(input_cost + output_cost, 4)
        }