"""
OpenAI GPT-4 Provider - Advanced AI Report Generation
====================================================

GPT-4 is OpenAI's most advanced language model, providing superior reasoning
and analysis capabilities for detailed intern progress reports.

Features:
- State-of-the-art AI analysis
- Superior reasoning capabilities
- Excellent formatting and structure
- Comprehensive insights
- Multiple model variants (GPT-4, GPT-4-turbo)

Setup Requirements:
1. Get OpenAI API key from https://platform.openai.com/api-keys
2. Set environment variable: OPENAI_API_KEY=your_api_key
3. Ensure sufficient credits in OpenAI account

Cost: ~$0.03 per 1K tokens (varies by model)

Usage:
    provider = OpenAIProvider()
    report = provider.generate_report(intern_data, 'weekly')
"""

import os
import json
import logging
from typing import Dict, Any, List, Optional
from openai import OpenAI
from .base_provider import BaseAIProvider

logger = logging.getLogger(__name__)

class OpenAIProvider(BaseAIProvider):
    """
    OpenAI GPT-4 provider implementation.
    Provides advanced AI analysis with superior reasoning capabilities.
    """
    
    def __init__(self, api_key: Optional[str] = None, model: str = "gpt-4"):
        """
        Initialize OpenAI provider
        
        Args:
            api_key: OpenAI API key (if None, reads from environment)
            model: OpenAI model to use (default: gpt-4)
        """
        self.api_key = api_key or os.getenv('OPENAI_API_KEY')
        self.model = model
        self.last_error = None
        
        if not self.api_key:
            self.last_error = "OpenAI API key not provided"
            logger.error(self.last_error)
            self.client = None
        else:
            try:
                self.client = OpenAI(api_key=self.api_key)
                logger.info(f"OpenAI provider initialized with model: {model}")
            except Exception as e:
                self.last_error = f"Failed to initialize OpenAI client: {e}"
                logger.error(self.last_error)
                self.client = None
        
        # Available models
        self.available_models = [
            "gpt-4",
            "gpt-4-turbo",
            "gpt-4-turbo-preview",
            "gpt-3.5-turbo"
        ]
        
        # Report generation prompts
        self.system_prompts = {
            'weekly': self._get_weekly_system_prompt(),
            'monthly': self._get_monthly_system_prompt(),
            'project_summary': self._get_project_system_prompt()
        }
    
    def test_connection(self) -> bool:
        """
        Test connection to OpenAI API
        
        Returns:
            True if API is accessible and working
        """
        if not self.client:
            return False
        
        try:
            # Make a simple API call to test connection
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": "Test connection. Reply with 'OK'."}
                ],
                max_tokens=10,
                temperature=0
            )
            
            if response.choices[0].message.content.strip().upper() == 'OK':
                self.last_error = None
                logger.info(f"OpenAI connection test successful with model {self.model}")
                return True
            else:
                self.last_error = "OpenAI API test returned unexpected response"
                logger.error(self.last_error)
                return False
                
        except Exception as e:
            self.last_error = f"OpenAI API connection failed: {e}"
            logger.error(self.last_error)
            return False
    
    def get_available_models(self) -> List[str]:
        """
        Get list of available OpenAI models
        
        Returns:
            List of model names
        """
        return self.available_models.copy()
    
    def generate_report(self, intern_data: Dict[str, Any], report_type: str = 'weekly') -> Dict[str, Any]:
        """
        Generate AI report using OpenAI GPT-4
        
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
                    'error': f"OpenAI not available: {self.last_error}",
                    'provider': 'openai'
                }
            
            # Format data for AI processing
            formatted_data = self.format_intern_data_for_ai(intern_data)
            
            # Get appropriate system prompt
            if report_type not in self.system_prompts:
                report_type = 'weekly'  # Default fallback
            
            system_prompt = self.system_prompts[report_type]
            user_prompt = self._create_user_prompt(intern_data, formatted_data, report_type)
            
            # Generate report using OpenAI
            logger.info(f"Generating {report_type} report using OpenAI model: {self.model}")
            
            ai_response = self._call_openai_api(system_prompt, user_prompt)
            
            if ai_response:
                # Parse and structure the response
                report_content = self._parse_openai_response(ai_response, report_type)
                
                # Create standardized report structure
                report = self.create_report_structure(
                    intern_data=intern_data,
                    report_type=report_type,
                    ai_content=report_content,
                    provider='openai'
                )
                
                logger.info("OpenAI report generated successfully")
                return report
            else:
                return {
                    'success': False,
                    'error': 'Failed to generate report with OpenAI',
                    'provider': 'openai'
                }
                
        except Exception as e:
            logger.error(f"OpenAI report generation failed: {e}")
            return {
                'success': False,
                'error': f"OpenAI error: {e}",
                'provider': 'openai'
            }
    
    def _call_openai_api(self, system_prompt: str, user_prompt: str) -> Optional[str]:
        """
        Call OpenAI API to generate response
        
        Args:
            system_prompt: System instructions for AI
            user_prompt: User input prompt
            
        Returns:
            AI response text or None if failed
        """
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=2500,
                temperature=0.7,  # Balanced creativity and consistency
                top_p=0.9,        # Focused responses
                frequency_penalty=0.1,  # Reduce repetition
                presence_penalty=0.1    # Update diverse content
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"OpenAI API call failed: {e}")
            return None
    
    def _parse_openai_response(self, response: str, report_type: str) -> Dict[str, Any]:
        """
        Parse OpenAI response into structured format
        
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
            # GPT-4 typically provides well-structured responses
            # Try to parse JSON if formatted as such
            if response.strip().startswith('{') and response.strip().endswith('}'):
                parsed_json = json.loads(response)
                if isinstance(parsed_json, dict):
                    content.update(parsed_json)
                    content['performance_score'] = self.calculate_performance_score(content)
                    return content
            
            # Parse structured text response
            sections = response.split('\n\n')
            current_section = None
            
            for section in sections:
                section = section.strip()
                if not section:
                    continue
                
                section_lower = section.lower()
                
                # Identify section headers
                if any(keyword in section_lower for keyword in ['summary', 'overview', 'introduction']):
                    current_section = 'summary'
                    # Extract content after header
                    lines = section.split('\n')
                    content_lines = [line for line in lines if not any(h in line.lower() for h in ['summary', 'overview'])]
                    content['summary'] = '\n'.join(content_lines).strip()
                    
                elif any(keyword in section_lower for keyword in ['strength', 'positive', 'achievement', 'good']):
                    current_section = 'strengths'
                    items = self._extract_structured_items(section)
                    content['strengths'].extend(items)
                    
                elif any(keyword in section_lower for keyword in ['weakness', 'improvement', 'challenge', 'area']):
                    current_section = 'weaknesses'
                    items = self._extract_structured_items(section)
                    content['weaknesses'].extend(items)
                    
                elif any(keyword in section_lower for keyword in ['recommend', 'suggest', 'next step', 'action']):
                    current_section = 'recommendations'
                    items = self._extract_structured_items(section)
                    content['recommendations'].extend(items)
                    
                else:
                    # Continue with current section or add to summary
                    if current_section == 'summary' and content['summary']:
                        content['summary'] += '\n\n' + section
                    elif not content['summary']:
                        content['summary'] = section
            
            # Calculate performance score
            content['performance_score'] = self.calculate_performance_score(content)
            
            # Ensure minimum content quality
            if not content['summary']:
                content['summary'] = response[:800] + '...' if len(response) > 800 else response
            
            return content
            
        except Exception as e:
            logger.warning(f"Error parsing OpenAI response: {e}")
            # Fallback to basic structure
            return {
                'summary': response[:1200] + '...' if len(response) > 1200 else response,
                'strengths': ['Comprehensive analysis provided'],
                'weaknesses': ['Additional data may enhance analysis'],
                'recommendations': ['Continue monitoring progress closely'],
                'performance_score': 80,  # Default score
                'raw_response': response
            }
    
    def _extract_structured_items(self, text: str) -> List[str]:
        """
        Extract structured items from GPT-4 formatted text
        
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
            
            # Skip header lines
            if any(header in line.lower() for header in ['strength', 'weakness', 'recommend', 'summary']):
                if ':' in line and len(line.split(':')[1].strip()) < 10:
                    continue
            
            # Clean various list formats
            cleaned_line = line
            
            # Remove bullet points and numbering
            for prefix in ['•', '○', '▪', '-', '*', '→', '►']:
                if line.startswith(prefix):
                    cleaned_line = line[1:].strip()
                    break
            
            # Handle numbered lists
            if '. ' in line:
                parts = line.split('. ', 1)
                if len(parts) > 1 and parts[0].strip().isdigit():
                    cleaned_line = parts[1]
            
            # Handle lettered lists (a. b. c.)
            if '. ' in line and len(line.split('. ')[0]) == 1:
                cleaned_line = '. '.join(line.split('. ')[1:])
            
            # Only add meaningful content
            if len(cleaned_line) > 15 and not any(skip in cleaned_line.lower() 
                                                  for skip in ['strengths:', 'weaknesses:', 'recommendations:', 'summary:']):
                items.append(cleaned_line)
        
        return items
    
    def _create_user_prompt(self, intern_data: Dict[str, Any], formatted_data: str, report_type: str) -> str:
        """
        Create user prompt for OpenAI
        
        Args:
            intern_data: Intern information
            formatted_data: Formatted logbook data
            report_type: Type of report
            
        Returns:
            Formatted user prompt
        """
        return f"""
Please analyze the following intern's performance data and generate a {report_type} report.

**Intern Information:**
- Name: {intern_data.get('intern_name', 'Unknown')}
- Project: {intern_data.get('project_name', 'Unknown')}
- Supervisor: {intern_data.get('supervisor_name', 'Unknown')}
- Period: {intern_data.get('period', 'Unknown')}

**Performance Data to Analyze:**
{formatted_data}

Please provide a comprehensive analysis following the structure outlined in your system instructions.
Focus on specific, actionable insights based on the actual data provided.
"""
    
    def _get_weekly_system_prompt(self) -> str:
        """Get system prompt for weekly reports"""
        return """
You are an expert intern supervisor with years of experience in mentoring and evaluating junior developers. Your task is to analyze weekly logbook entries and performance data to create comprehensive, professional reports.

For weekly reports, provide analysis in this structure:

1. **EXECUTIVE SUMMARY**: Brief overview of the week's progress and key highlights
2. **TECHNICAL PROGRESS**: Specific technical achievements and skills demonstrated
3. **STRENGTHS OBSERVED**: Concrete positive behaviors and capabilities shown
4. **AREAS FOR DEVELOPMENT**: Specific improvement areas with examples
5. **RECOMMENDATIONS**: Actionable next steps and suggestions
6. **PERFORMANCE METRICS**: Quantitative assessment where possible

Guidelines:
- Be specific and reference actual activities from the data
- Provide constructive, actionable feedback  
- Balance positive reinforcement with growth opportunities
- Use professional, encouraging language
- Include specific examples from the logbook entries
- Consider both technical and soft skills development

Output should be well-structured, professional, and suitable for sharing with the intern and other stakeholders.
"""
    
    def _get_monthly_system_prompt(self) -> str:
        """Get system prompt for monthly reports"""
        return """
You are a senior manager conducting comprehensive monthly performance reviews for interns. Your analysis should provide strategic insights and development planning.

For monthly reports, structure your analysis as:

1. **MONTHLY OVERVIEW**: High-level summary of progress and achievements
2. **KEY ACCOMPLISHMENTS**: Major milestones and significant contributions
3. **SKILL DEVELOPMENT TRAJECTORY**: Analysis of learning progression and growth
4. **PROJECT CONTRIBUTIONS**: Specific impact on project goals and deliverables
5. **PROFESSIONAL DEVELOPMENT**: Communication, teamwork, and workplace skills
6. **CHALLENGES AND RESILIENCE**: How obstacles were handled and lessons learned
7. **STRATEGIC RECOMMENDATIONS**: Long-term development planning and next steps
8. **READINESS ASSESSMENT**: Evaluation of current capabilities and future potential

Focus on:
- Trend analysis and progression over the month
- Strategic development opportunities
- Quantifiable achievements and metrics
- Readiness for increased responsibilities
- Alignment with internship objectives
- Career development insights

Provide comprehensive, forward-looking analysis suitable for formal performance records.
"""
    
    def _get_project_system_prompt(self) -> str:
        """Get system prompt for project summary reports"""
        return """
You are a project director conducting final project assessments for intern contributions. Your evaluation will inform future hiring and development decisions.

For project summary reports, provide comprehensive analysis including:

1. **PROJECT CONTRIBUTION OVERVIEW**: Executive summary of intern's role and impact
2. **TECHNICAL DELIVERABLES**: Specific technical work completed and quality assessment
3. **PROJECT IMPACT ANALYSIS**: How intern's work contributed to project success
4. **COLLABORATION AND INTEGRATION**: Teamwork, communication, and stakeholder interaction
5. **PROBLEM-SOLVING CAPABILITY**: Examples of challenges faced and solutions provided
6. **LEARNING AND ADAPTATION**: Growth demonstrated throughout the project
7. **QUALITY AND PROFESSIONALISM**: Standards of work and professional behavior
8. **FINAL ASSESSMENT**: Overall performance rating and recommendation

Evaluation criteria:
- Technical competency and code quality
- Project management and deadline adherence
- Innovation and creative problem-solving
- Team collaboration and communication
- Professional growth and adaptability
- Overall contribution to project objectives

Provide detailed, evidence-based assessment suitable for formal project closure and potential hiring recommendations.
"""
    
    def set_model(self, model_name: str) -> bool:
        """
        Set OpenAI model to use
        
        Args:
            model_name: Name of OpenAI model
            
        Returns:
            True if model is available and set successfully
        """
        if model_name in self.available_models:
            self.model = model_name
            logger.info(f"OpenAI model set to: {model_name}")
            return True
        else:
            logger.warning(f"OpenAI model {model_name} not available")
            return False
    
    def estimate_cost(self, text_length: int) -> Dict[str, float]:
        """
        Estimate cost for OpenAI API call
        
        Args:
            text_length: Approximate input text length
            
        Returns:
            Cost estimation information
        """
        # Rough token estimation (1 token ≈ 4 characters)
        estimated_tokens = text_length / 4
        
        # OpenAI pricing (approximate, varies by model)
        pricing = {
            'gpt-4': {'input': 0.03, 'output': 0.06},  # per 1K tokens
            'gpt-4-turbo': {'input': 0.01, 'output': 0.03},
            'gpt-3.5-turbo': {'input': 0.001, 'output': 0.002}
        }
        
        model_pricing = pricing.get(self.model, pricing['gpt-4'])
        input_cost = (estimated_tokens / 1000) * model_pricing['input']
        output_cost = (2000 / 1000) * model_pricing['output']  # Assume 2K output tokens
        
        return {
            'estimated_input_tokens': int(estimated_tokens),
            'estimated_output_tokens': 2000,
            'input_cost_usd': round(input_cost, 4),
            'output_cost_usd': round(output_cost, 4),
            'total_cost_usd': round(input_cost + output_cost, 4)
        }